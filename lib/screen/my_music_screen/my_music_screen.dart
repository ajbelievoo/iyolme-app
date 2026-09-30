import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/model/post_story/music/music_model.dart';
import 'package:shortzz/screen/my_music_screen/my_music_controller.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// "My Music" picker — opened from the reel-create music sheet's "+"
/// button. Lists the user's own HiTune sounds: AI Studio generated
/// songs and HiTune Distribution releases. Tapping a song returns it
/// to the sheet which runs the normal select/trim flow.
class MyMusicScreen extends StatelessWidget {
  const MyMusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MyMusicController());
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: scaffoldBackgroundColor(context),
        elevation: 0,
        iconTheme: IconThemeData(color: textDarkGrey(context)),
        title: Text('My Music',
            style: TextStyleCustom.outFitMedium500(
                fontSize: 18, color: textDarkGrey(context))),
        actions: [
          TextButton.icon(
            onPressed: controller.onOpenAiStudio,
            icon: Icon(Icons.auto_awesome,
                size: 18, color: themeAccentSolid(context)),
            label: Text('AI Studio',
                style: TextStyleCustom.outFitMedium500(
                    fontSize: 13, color: themeAccentSolid(context))),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(
        () => controller.isLoading.value && !controller.fetched.value
            ? const LoaderWidget()
            : controller.notLinked.value
                ? _NotLinkedView(controller: controller)
                : RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: _SongList(controller: controller),
                  ),
      ),
    );
  }
}

class _NotLinkedView extends StatelessWidget {
  final MyMusicController controller;
  const _NotLinkedView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 56, color: textLightGrey(context)),
            const SizedBox(height: 16),
            Text('Connect your HiTune account',
                textAlign: TextAlign.center,
                style: TextStyleCustom.outFitMedium500(
                    fontSize: 17, color: textDarkGrey(context))),
            const SizedBox(height: 8),
            Text(
                'Link HiTune Music to see your AI Studio songs and '
                'distributed releases here.',
                textAlign: TextAlign.center,
                style: TextStyleCustom.outFitRegular400(
                    fontSize: 13, color: textLightGrey(context))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: controller.onConnectHitune,
              icon: const Icon(Icons.music_note, size: 18),
              label: const Text('Continue with HiTune'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeAccentSolid(context),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongList extends StatelessWidget {
  final MyMusicController controller;
  const _SongList({required this.controller});

  @override
  Widget build(BuildContext context) {
    final ai = controller.aiSongs;
    final releases = controller.releases;
    final empty = ai.isEmpty && releases.isEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        _AiStudioBanner(onTap: controller.onOpenAiStudio),
        const SizedBox(height: 14),
        if (empty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: NoDataView(showShow: true, child: SizedBox()),
          )
        else ...[
          if (ai.isNotEmpty) ...[
            _SectionHeader('AI Studio Songs', context),
            ...ai.map((m) => _SongTile(
                  music: m,
                  onTap: () => controller.onTapMusic(m),
                )),
          ],
          if (releases.isNotEmpty) ...[
            _SectionHeader('My Releases', context),
            ...releases.map((m) => _SongTile(
                  music: m,
                  onTap: () => controller.onTapMusic(m),
                )),
          ],
        ],
      ],
    );
  }
}

class _AiStudioBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AiStudioBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF00B7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create a song in AI Studio',
                      style: TextStyleCustom.outFitMedium500(
                          fontSize: 15, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Generate with AI on HiTune — it appears here',
                      style: TextStyleCustom.outFitRegular400(
                          fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

Widget _SectionHeader(String title, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(title,
        style: TextStyleCustom.outFitMedium500(
            fontSize: 15, color: textDarkGrey(context))),
  );
}

class _SongTile extends StatelessWidget {
  final Music music;
  final VoidCallback onTap;
  const _SongTile({required this.music, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CustomImage(
              size: const Size(52, 52),
              image: music.image?.addBaseURL(),
              radius: 10,
              fullName: music.title,
              isShowPlaceHolder: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(music.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyleCustom.outFitMedium500(
                                fontSize: 15,
                                color: textDarkGrey(context))),
                      ),
                      if (music.isAiGenerated) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(music.aiBadge ?? 'AI',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 9)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(music.artist ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyleCustom.outFitRegular400(
                          fontSize: 12, color: textLightGrey(context))),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline,
                color: themeAccentSolid(context), size: 26),
          ],
        ),
      ),
    );
  }
}
