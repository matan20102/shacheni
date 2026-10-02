import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// Counterparty card. Phone/WhatsApp are revealed only while the transaction is live
/// (BR-K3); the apartment only when it is needed (BR-K2, delivery → accepted helper).
class ContactCard extends StatelessWidget {
  const ContactCard(this.person, {super.key, this.showContact = false, this.apartment, this.title});
  final Person person;
  final bool showContact;
  final String? apartment;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: AppText.smallBold),
            const SizedBox(height: 10),
          ],
          PersonLine(
            person,
            onTap: () => context.push('/profile/${person.id}'),
            trailing: apartment == null ? null : StatusChip(l.apartmentLabel(apartment!), tone: Tone.primary, icon: Icons.door_front_door_outlined),
          ),
          const SizedBox(height: 12),
          if (showContact)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: () => showSnack(context, '${l.call}: ${person.phone}'),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(l.call),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: () => showSnack(context, '${l.whatsapp}: ${person.phone}'),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: Text(l.whatsapp),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.inkFaint),
                const SizedBox(width: 6),
                Expanded(child: Text(l.contactAfter, style: AppText.tiny)),
              ],
            ),
        ],
      ),
    );
  }
}
