import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

/// The exact programme text from the Moonlight Agent spec — shown before
/// anyone creates an agency, and again on the dashboard.
const String kAgentInviteMessage =
    'Invite new people to Moonlight. Earn 10% each time your invited host '
    'earns from livestreaming or video chat. Receive 5% each time your hosts '
    'buy coins. Receive 60 coins when your host joins the free task platform. '
    'An agent with the highest performing rate earns huge thank you rewards '
    'from Moonlight. You will be added to Moonlight agency WhatsApp Group '
    'once your invited hosts reach 10 persons.';

class AgentScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  const AgentScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      appBar: AppBar(
        backgroundColor: AppColors.bgBottom,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: actions,
      ),
      body: SafeArea(child: body),
    );
  }
}

class AgentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AgentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: child,
  );
}

class AgentAvatar extends StatelessWidget {
  final String? url;
  final double size;
  const AgentAvatar({super.key, this.url, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: (url == null || url!.isEmpty)
            ? Container(
                color: AppColors.divider,
                child: const Icon(Icons.groups_rounded, color: Colors.white54),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.divider,
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Colors.white54,
                  ),
                ),
              ),
      ),
    );
  }
}

class AgentPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const AgentPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: busy ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary_,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}

InputDecoration agentInput(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  labelStyle: const TextStyle(color: Colors.white60),
  hintStyle: const TextStyle(color: Colors.white30),
  filled: true,
  fillColor: Colors.white.withValues(alpha: 0.06),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
);
