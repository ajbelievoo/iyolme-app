import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/api/moderator_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/screen/report_sheet/report_sheet.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';

class ReportSheetController extends BaseController {
  List<ReportReason> reports =
      SessionManager.instance.getSettings()?.reportReason ?? [];
  Rx<ReportReason?> selectedValue = Rx(null);
  int reportId;
  ReportType reportType;

  TextEditingController descriptionController = TextEditingController();

  ReportSheetController(this.reportId, this.reportType);

  @override
  void onReady() {
    super.onReady();
    selectedValue.value = reports.isNotEmpty ? reports.first : null;
  }

  void onReportSubmit() {
    if (descriptionController.text.isEmpty) {
      return showSnackBar(LKey.provideReportReason.tr);
    }
    if (reportId == -1) {
      return Loggers.error('Invalid Post Id : $reportId');
    }
    if (reportType == ReportType.post) {
      _reportPost();
    } else {
      _reportUser();
    }
  }

  void _reportPost() async {
    showLoader();
    StatusModel model = await PostService.instance.reportPost(
        postId: reportId,
        reason: selectedValue.value?.title ?? '',
        description: descriptionController.text.trim());
    stopLoader();

    // Safely close the bottom sheet/dialog without assuming SnackbarController state.
    try {
      Get.back();
    } catch (_) {
      // ignore navigation errors
    }
    if (model.status == true) {
      showSnackBar(LKey.reportSubmitted.tr);
    } else {
      showSnackBar(model.message?.tr.capitalizeFirst);
    }
  }

  void _reportUser() async {
    showLoader();
    StatusModel model = await UserService.instance.reportPost(
        userId: reportId,
        reason: selectedValue.value?.title ?? '',
        description: descriptionController.text.trim());
    stopLoader();

    // Safely close the bottom sheet/dialog without assuming SnackbarController state.
    try {
      Get.back();
    } catch (_) {
      // ignore navigation errors
    }
    if (model.status == true) {
      showSnackBar(LKey.reportSubmitted.tr);
    } else {
      showSnackBar(model.message?.tr.capitalizeFirst);
    }
  }

  Future<void> onModeratorDeletePost() async {
    final isModerator = SessionManager.instance.isModerator.value == 1;
    if (!isModerator) return;
    if (reportType != ReportType.post) return;
    if (reportId <= 0) {
      return showSnackBar('Invalid Post ID');
    }

    showLoader();
    final model =
        await ModeratorService.instance.moderatorDeletePost(postId: reportId);
    stopLoader();

    try {
      Get.back();
    } catch (_) {}

    if (model.status == true) {
      if (Get.isRegistered<ProfileScreenController>(
          tag: ProfileScreenController.tag)) {
        final controller = Get.find<ProfileScreenController>(
            tag: ProfileScreenController.tag);
        controller.reels.removeWhere((e) => e.id == reportId);
        controller.reels.refresh();
      }

      if (Get.isRegistered<ReelsScreenController>(tag: ReelsScreenController.tag)) {
        final reelsController =
            Get.find<ReelsScreenController>(tag: ReelsScreenController.tag);
        reelsController.reels.removeWhere((e) => e.id == reportId);
        reelsController.reels.refresh();
      }

      showSnackBar(LKey.delete.tr);
    } else {
      showSnackBar(model.message?.tr.capitalizeFirst);
    }
  }
}
