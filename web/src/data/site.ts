import appAddFoodImage from '../assets/app-images/app-add-food.png';
import appCalendarImage from '../assets/app-images/app-calendar.png';
import appHistoryImage from '../assets/app-images/app-history.png';
import appHomeImage from '../assets/app-images/app-home.png';
import appInsightsImage from '../assets/app-images/app-insights.png';
import appSettingsImage from '../assets/app-images/app-settings.png';
import appShareImage from '../assets/app-images/app-share.png';
import appSharingSettingsImage from '../assets/app-images/app-sharing-settings.png';
import appFullUnlockImage from '../assets/app-images/app-full-unlock.png';

export const site = {
	name: 'MACROS',
	tagline: 'Track calories and macros without creating an account.',
	description:
		'MACROS is a local-first iPhone app for logging calories, protein, carbs, and fat with barcode scans, nutrition label photos, and fast manual entry.',
	navItems: [
		{ href: '/', label: 'Home' },
		{ href: '/about', label: 'About' },
		{ href: '/privacy', label: 'Privacy' },
		{ href: '/support', label: 'Support' },
	],
	heroShowcase: {
		src: appHomeImage,
		alt: 'MACROS dashboard with a full day of food logged',
	},
	screenshots: [
		{
			src: appHomeImage,
			alt: 'MACROS daily dashboard with logged meals and filled macro rings',
			title: 'Daily macro summary',
		},
		{
			src: appAddFoodImage,
			alt: 'MACROS add food screen with search, common foods, barcode scan, and label scan actions',
			title: 'Add food quickly',
		},
		{
			src: appSettingsImage,
			alt: 'MACROS settings screen with goals and saved custom foods',
			title: 'Goals and saved foods',
		},
		{
			src: appInsightsImage,
			alt: 'MACROS insights screen with nutrition trends and macro charts',
			title: 'Insights and trends',
		},
		{
			src: appHistoryImage,
			alt: 'MACROS history screen with a full week of logged food progress',
			title: 'Weekly history',
		},
		{
			src: appCalendarImage,
			alt: 'MACROS expanded calendar history view with macro progress',
			title: 'Calendar overview',
		},
		{
			src: appSharingSettingsImage,
			alt: 'MACROS sharing settings screen with invite link controls',
			title: 'Private invite links',
		},
		{
			src: appFullUnlockImage,
			alt: 'MACROS Full Unlock purchase screen',
			title: 'Full Unlock',
		},
		{
			src: appShareImage,
			alt: 'iOS share sheet for a MACROS daily summary image',
			title: 'Share daily progress',
		},
	],
	supportChecklist: [
		'Share the screen, flow, or food entry that caused the issue.',
		'Include the email address where you want the reply.',
		'Mention what you expected to happen and what happened instead.',
	],
} as const;
