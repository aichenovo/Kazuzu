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
    _customLinkController.text = setting.get('customPluginLink') ?? '';

    // 如果有自定义链接，设置给 controller 并刷新
    if (_customLinkController.text.isNotEmpty) {
      pluginsController.pluginRepoUrl = _customLinkController.text;
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

      // 更新 controller 的仓库地址
      pluginsController.pluginRepoUrl = link;

      _handleRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自定义链接已保存')),
      );
    }
  }

  // 刷新规则列表
  void _handleRefresh() async {
    if (!loading) {
      setState(() {
        loading = true;
        timeout = false;
      });

      enableGitProxy =
          setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);

      pluginsController.queryPluginHTTPList().then((_) {
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
          var plugin = sortedList[index];
          return Card(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ListTile(
              title: Text(
                plugin.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildTag(plugin.version, Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 5),
                      _buildTag(plugin.useNativePlayer ? 'native' : 'webview',
                          Theme.of(context).colorScheme.primary),
                      if (plugin.antiCrawlerEnabled) ...[
                        const SizedBox(width: 5),
                        _buildTag('captcha', Theme.of(context).colorScheme.tertiary,
                            textColor: Theme.of(context).colorScheme.onTertiary),
                      ]
                    ],
                  ),
                  if (plugin.lastUpdate > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '更新时间: ${DateTime.fromMillisecondsSinceEpoch(plugin.lastUpdate).toString().split('.')[0]}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
              trailing: TextButton(
                onPressed: () async {
                  String status = pluginsController.pluginStatus(plugin);
                  if (status == 'install' || status == 'update') {
                    KazumiDialog.showToast(
                        message: status == 'install' ? '导入中' : '更新中');
                    int res =
                        await pluginsController.tryUpdatePluginByName(plugin.name);
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
                child: Text(pluginsController.pluginStatus(plugin) == 'install'
                    ? '安装'
                    : (pluginsController.pluginStatus(plugin) == 'installed'
                        ? '已安装'
                        : '更新')),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildTag(String text, Color bgColor, {Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor ?? Colors.white),
      ),
    );
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
            onPressed: _handleRefresh,
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
                onPressed: _handleRefresh,
                tooltip: '刷新规则列表',
                icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Column(
          children: [
            // 自定义仓库链接输入框
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
                        border: const OutlineInputBorder(),
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