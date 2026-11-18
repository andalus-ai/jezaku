import 'package:jejaku/features/legal/models/legal_document.dart';

/// Plain-language drafts that describe what the app actually does today.
/// They are marked as drafts until reviewed; replace the text, bump the
/// version and set `isDraft: false` when counsel signs off.
const legalDocuments = <LegalDocument>[
  _terms,
  _privacy,
  _community,
];

LegalDocument legalDocumentFor(LegalDocumentId id) {
  return legalDocuments.firstWhere((document) => document.id == id);
}

const _terms = LegalDocument(
  id: LegalDocumentId.terms,
  title: 'Terms of use',
  version: '0.1',
  effectiveDate: '2026-11-18',
  summary: 'The rules for using Jezaku and what you can expect from us.',
  sections: [
    LegalSection(
      heading: 'Using Jezaku',
      paragraphs: [
        'Jezaku lets you leave photos, videos and notes anchored to real '
            'places, and see what others have left there through augmented '
            'reality.',
        'You are responsible for what you place and for being safe where you '
            'place it. Do not use the app while driving, crossing roads or '
            'anywhere that looking at a screen is dangerous.',
      ],
    ),
    LegalSection(
      heading: 'Your content',
      paragraphs: [
        'What you create stays yours. By publishing a memory you allow Jezaku '
            'to store it and show it to the people you chose, for as long as '
            'it stays published.',
        'Only publish what you have the right to share. Do not publish '
            'photos of people who have not agreed, or of places where '
            'photography is not allowed.',
      ],
    ),
    LegalSection(
      heading: 'Where you may place memories',
      paragraphs: [
        'Do not anchor content on private property without permission, on '
            'restricted sites, or in a way that could mislead people about '
            'what is real, for example fake notices or official signs.',
      ],
    ),
    LegalSection(
      heading: 'Families and guardians',
      paragraphs: [
        'Accounts used by children can be linked to a guardian. Guardians may '
            'approve what a child publishes and set where a child may use the '
            'app. If you are a guardian you are responsible for those choices.',
      ],
    ),
    LegalSection(
      heading: 'Removing content and accounts',
      paragraphs: [
        'We may remove content that breaks these terms or the community '
            'guidelines, and may limit or close accounts that repeatedly do '
            'so. You can delete your own memories at any time.',
      ],
    ),
    LegalSection(
      heading: 'Availability and changes',
      paragraphs: [
        'Jezaku is provided as it is. Features, including location accuracy '
            'and AR tracking, depend on your device and surroundings and may '
            'not always work.',
        'When these terms change in a way that matters, we will tell you in '
            'the app and ask you to accept the new version.',
      ],
    ),
    LegalSection(
      heading: 'Contact',
      paragraphs: ['Contact details will be added before release.'],
    ),
  ],
);

const _privacy = LegalDocument(
  id: LegalDocumentId.privacy,
  title: 'Privacy policy',
  version: '0.1',
  effectiveDate: '2026-11-18',
  summary: 'What Jezaku collects, why, and the choices you have.',
  sections: [
    LegalSection(
      heading: 'What we use',
      paragraphs: [
        'Location: to place a memory where you are and to show memories near '
            'you. You can choose to share only an approximate location in '
            'Privacy and safety.',
        'Camera, microphone and motion sensors: to capture photos, video and '
            'sound for a memory and to keep AR content steady. The app asks '
            'before using each of them, and you can turn them off in your '
            'device settings.',
        'Your profile: the display name and handle you choose.',
      ],
    ),
    LegalSection(
      heading: 'Where your data is kept',
      paragraphs: [
        'Memories, settings and your profile are stored on your device. When '
            'you publish, the memory and the location you chose to share are '
            'sent to Jezaku so the people you chose can see it.',
        'Items waiting to upload stay on your device until they are sent.',
      ],
    ),
    LegalSection(
      heading: 'Who can see what',
      paragraphs: [
        'Each memory is private, visible to friends, or public, as you set '
            'it. Comments on a memory are limited to its owner and the '
            "owner's friends, and you only see comments from people you are "
            'connected with.',
        'Blocked accounts cannot see or comment on your memories.',
      ],
    ),
    LegalSection(
      heading: 'Children',
      paragraphs: [
        'For accounts linked to a guardian, the guardian can see what the '
            'child publishes and the places they are allowed to use the app. '
            'Guardian alerts about leaving a safe zone use the location the '
            'child shares.',
      ],
    ),
    LegalSection(
      heading: 'Your choices',
      paragraphs: [
        'You can change who sees a memory, turn precise location off, hide '
            'your profile from discovery, block accounts, clear cached media '
            'and delete memories at any time from the app.',
      ],
    ),
    LegalSection(
      heading: 'Diagnostics',
      paragraphs: [
        'AR diagnostics are kept on your device. They leave it only if you '
            'choose to export and share them.',
      ],
    ),
    LegalSection(
      heading: 'Contact',
      paragraphs: ['Contact details will be added before release.'],
    ),
  ],
);

const _community = LegalDocument(
  id: LegalDocumentId.community,
  title: 'Community guidelines',
  version: '0.1',
  effectiveDate: '2026-11-18',
  summary: 'How we keep shared places welcoming and safe.',
  sections: [
    LegalSection(
      heading: 'Be kind',
      paragraphs: [
        'No harassment, hate, threats or content meant to humiliate someone. '
            'Comments and memories that do this will be removed.',
      ],
    ),
    LegalSection(
      heading: 'Respect people and places',
      paragraphs: [
        'Do not share photos of people without their agreement, or content '
            'that shows where someone lives or works without their consent.',
        'Keep memories off private property and out of places where being '
            'distracted is dangerous.',
      ],
    ),
    LegalSection(
      heading: 'Keep it safe for everyone',
      paragraphs: [
        'No sexual content involving minors, graphic violence, or content '
            'that encourages self-harm or dangerous acts. Content like this '
            'is removed and may be reported to the authorities.',
      ],
    ),
    LegalSection(
      heading: 'Be honest',
      paragraphs: [
        'No impersonation, scams, spam, or fake official notices.',
      ],
    ),
    LegalSection(
      heading: 'Reporting and blocking',
      paragraphs: [
        'You can report any memory or comment, and block an account in '
            'Privacy and safety. Reports are reviewed by a moderator, and '
            'repeated or serious breaches can lead to removal from Jezaku.',
      ],
    ),
  ],
);
