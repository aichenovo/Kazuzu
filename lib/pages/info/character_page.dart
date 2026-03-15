import 'package:flutter/material.dart';
import 'package:aura/request/tmdb.dart';
import 'package:aura/bean/card/network_img_layer.dart';
import 'package:aura/bean/widget/error_widget.dart';

class CharacterPage extends StatefulWidget {
  const CharacterPage({super.key, required this.characterID});

  final int characterID;

  @override
  State<CharacterPage> createState() => _CharacterPageState();
}

class _CharacterPageState extends State<CharacterPage> {
  Map<String, dynamic>? person;
  bool loadingPerson = true;

  Future<void> loadPerson() async {
    setState(() {
      loadingPerson = true;
    });
    person = await TMDBHTTP.getPersonDetails(widget.characterID);
    if (mounted) {
      setState(() {
        loadingPerson = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadPerson();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: characterInfoBody);
  }

  Widget get characterInfoBody {
    const imageBase = 'https://image.tmdb.org/t/p/';
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LayoutBuilder(builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: loadingPerson
                  ? const Center(child: CircularProgressIndicator())
                  : (person == null
                      ? GeneralErrorWidget(
                          errMsg: '什么都没有找到 (´;ω;`)',
                          actions: [
                            GeneralErrorButton(
                              onPressed: () {
                                loadPerson();
                              },
                              text: '点击重试',
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: constraints.maxWidth * 0.3,
                                height: constraints.maxHeight,
                                child: NetworkImgLayer(
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  src: (() {
                                    final profilePath =
                                        (person?['profile_path'] ?? '')
                                            .toString();
                                    if (profilePath.isEmpty) return '';
                                    return '$imageBase/w500$profilePath';
                                  })(),
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (person?['name'] ?? '').toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .tertiary,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 4.0, bottom: 12.0),
                                          child: Text(
                                            (person?['known_for_department'] ??
                                                    '')
                                                .toString(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: Colors.grey[700],
                                                ),
                                          ),
                                        ),
                                        const Divider(),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          child: Text(
                                            '基本信息',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          (person?['place_of_birth'] ?? '')
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                          textAlign: TextAlign.justify,
                                        ),
                                        const SizedBox(height: 16.0),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          child: Text(
                                            '简介',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          (person?['biography'] ?? '')
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                          textAlign: TextAlign.justify,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
            ),
          ],
        );
      }),
    );
  }
}
