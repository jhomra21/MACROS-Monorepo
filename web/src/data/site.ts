import appAddFoodImage from '../assets/app-images/app-add-food.png';
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
	appStoreURL: '',
	navItems: [
		{ href: '/', label: 'Home' },
		{ href: '/about', label: 'About' },
		{ href: '/privacy', label: 'Privacy' },
		{ href: '/terms', label: 'Terms' },
		{ href: '/support', label: 'Support' },
	],
	whyMacros: [
		'No account required',
		'Free barcode and nutrition label scanning',
		'Your food logs stay on your phone',
		'Share daily totals only with people you choose',
	],
	freeFeatures: [
		'All food logging, barcode scanning, label scanning, and online packaged-food search',
		'Saved foods and meals, history, and widgets',
		'Daily share card and sharing circle',
		'Goal calculator and basic weight log',
		'Write nutrition to Apple Health',
		'One daily reminder',
	],
	proFeatures: [
		'Insights charts and weight trends',
		'Weight import from Apple Health',
		'Backup export and import',
		'Custom macro ring colors',
		'Multiple and smart reminders',
	],
	proPricing: '$2.99/month, $19.99/year with a 7-day free trial, or $49.99 once',
	faq: [
		{
			question: 'Do I need an account?',
			answer: 'No. Food logging works without an account. Sharing is optional and uses a separate sharing profile.',
		},
		{
			question: 'What is MACROS Pro?',
			answer: 'Pro unlocks Insights charts, weight trends, weight import from Apple Health, backup export and import, custom ring colors, and more reminder options.',
		},
		{
			question: 'Does it work offline?',
			answer: 'Your on-device logs and manual entry are available offline. Online packaged-food search needs a connection.',
		},
		{
			question: 'What leaves my phone?',
			answer: 'Search terms or barcodes go to our food-search service. If you turn on sharing, only your chosen display name and daily nutrition totals are shared, never individual foods.',
		},
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
