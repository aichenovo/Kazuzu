import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';

class PluginShopPage extends StatefulWidget {
  const PluginShopPage({super.key});

  @override
  State<PluginShopPage> createState() => _PluginShopPageState();
}

class _PluginShopPageState extends State<PluginShopPage> {
  Box setting = GStorage.setting;
  bool timeout = false;
  bool loading = false;
  late bool enableGitProxy;

  // 排序方式状态：false=按更新时间排序，true=按名称排序
  bool sortByName = false;
  final PluginsController pluginsController = Modular.get<PluginsController>();

  // 自定义链接控制器
  TextEditingController _customLinkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    enableGitProxy =
        setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);

    // 初始化自定义链接
    _customLinkController.text =
        setting.get('customPluginLink', '') ?? '';
    // 自动加载自定义链接的数据
    if (_customLinkController.text.isNotEmpty) {
      _handleRefresh();
    }
  }

  @override
  void dispose() {
    _customLinkController.dispose();
    super.dispose();
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  // 保存自定义链接并刷新列表
  void _saveCustomLinkAndRefresh() {
    String link = _customLinkController.text.trim();
    if (link.isNotEmpty) {
      setting.put('customPluginLink', link);
      _handleRefresh(customLink: link);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('自定义链接已保存')),
      );
    }
  }

  // 刷新规则列表，支持自定义链接
  void _handleRefresh({String? customLink}) async {
    if (!loading) {
      setState(() {
        loading = true;
        timeout = false;
      });
      enableGitProxy =
          setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);

      // 使用自定义链接查询
      String queryLink = customLink ?? _customLinkController.text.trim();
      pluginsController.queryPluginHTTPList(customLink: queryLink).then((_) {
        setState(() {
          loading = false;
        });
        if (pluginsController.pluginHTTPList.isEmpty) {
          setState(() {
            timeout = true;
          });
        }
      });
    }
  }

  void _toggleSort() {
    setState(() {
      sortByName = !sortByName;
    });
  }

  Widget get pluginHTTPListBody {
    return Observer(builder: (context) {
      var sortedList = List.from(pluginsController.pluginHTTPList);
      if (sortByName) {
        sortedList.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      } else {
        sortedList.sort((a, b) => b.lastUpdate.compareTo(a.lastUpdate));
      }

      return ListView.builder(
        itemCount: sortedList.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ListTile(
              title: Row(
                children: [
                  Text(
                    sortedList[index].name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 1.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Text(
                          sortedList[index].version,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.surface),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 1.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Text(
                          sortedList[index].useNativePlayer
                              ? "native"
                              : "webview",
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.surface),
                        ),
                      ),
                      if (sortedList[index].antiCrawlerEnabled) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 1.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiary,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Text(
                            'captcha',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onTertiary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (sortedList[index].lastUpdate > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '更新时间: ${DateTime.fromMillisecondsSinceEpoch(sortedList[index].lastUpdate).toString().split('.')[0]}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ],
              ),
              trailing: TextButton(
                onPressed: () async {
                  String status =
                      pluginsController.pluginStatus(sortedList[index]);
                  if (status == 'install' || status == 'update') {
                    KazumiDialog.showToast(
                        message: status == 'install' ? '导入中' : '更新中');
                    int res = await pluginsController
                        .tryUpdatePluginByName(sortedList[index].name);
                    if (res == 0) {
                      KazumiDialog.showToast(
                          message: status == 'install' ? '导入成功' : '更新成功');
                      setState(() {});
                    } else if (res == 1) {
                      KazumiDialog.showToast(
                          message:
                              'kazumi版本过低, 此规则不兼容当前版本');
                    } else if (res == 2) {
                      KazumiDialog.showToast(
                          message: status == 'install'
                              ? '导入规则失败'
                              : '更新规则失败');
                    }
                  }
                },
                child: Text(pluginsController
                            .pluginStatus(sortedList[index]) ==
                        'install'
                    ? '安装'
                    : (pluginsController.pluginStatus(sortedList[index]) ==
                            'installed')
                        ? '已安装'
                        : '更新'),
              ),
            ),
          );
        },
      );
    });
  }

  Widget get timeoutWidget {
    return Center(
      child: GeneralErrorWidget(
        errMsg:
            '啊咧（⊙.⊙） 无法访问远程仓库\n${enableGitProxy ? '镜像已启用' : '镜像已禁用'}',
        actions: [
          GeneralErrorButton(
            onPressed: () {
              Modular.to.pushNamed('/settings/webdav/');
            },
            text: enableGitProxy ? '禁用镜像' : '启用镜像',
          ),
          GeneralErrorButton(
            onPressed: () {
              _handleRefresh();
            },
            text: '刷新',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(
          title: const Text('规则仓库'),
          actions: [
            IconButton(
                onPressed: _toggleSort,
                tooltip: sortByName ? '按名称排序' : '按更新时间排序',
                icon: Icon(sortByName ? Icons.sort_by_alpha : Icons.access_time)),
            IconButton(
                onPressed: () {
                  _handleRefresh();
                },
                tooltip: '刷新规则列表',
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: Column(
          children: [
            // 自定义链接输入栏
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customLinkController,
                      decoration: InputDecoration(
                        labelText: '自定义插件仓库链接',
                        hintText: '请输入自定义链接',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveCustomLinkAndRefresh,
                    child: const Text('应用'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : (pluginsController.pluginHTTPList.isEmpty
                      ? timeoutWidget
                      : pluginHTTPListBody),
            ),
          ],
        ),
      ),
    );
  }
}