import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/widget/user_list.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/common/service/navigation/navigate_with_controller.dart';

class ViewersSheet extends StatefulWidget {
  final List<String> viewerIds;

  const ViewersSheet({super.key, required this.viewerIds});

  @override
  State<ViewersSheet> createState() => _ViewersSheetState();
}

class _ViewersSheetState extends State<ViewersSheet> {
  final RxList<User> users = <User>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _fetchViewers();
  }

  Future<void> _fetchViewers() async {
    isLoading.value = true;
    try {
      final futures = widget.viewerIds.map((id) {
        final uid = int.tryParse(id);
        if (uid != null) {
          return UserService.instance.fetchUserDetails(userId: uid);
        }
        return Future.value(null);
      });

      final results = await Future.wait(futures);
      final validUsers = results.whereType<User>().toList();
      users.assignAll(validUsers);
    } catch (e) {
      // Handle error
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            '${widget.viewerIds.length} Viewers',
            style: TextStyleCustom.outFitBold700(fontSize: 18),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: UserList<User>(
              users: users,
              isLoading: isLoading,
              onTap: (user) {
                  NavigationService.shared.openProfileScreen(user);
              },
              getProfilePhoto: (user) => user.profilePhoto ?? '',
              getUserName: (user) => user.username ?? '',
              getFullName: (user) => user.fullname ?? '',
              getVerified: (user) => user.isVerify ?? 0,
              getUserId: (user) => user.id,
            ),
          ),
        ],
      ),
    );
  }
}
