import appAddFoodImage from '../assets/app-images/app-add-food.png';
import appHistoryImage from '../assets/app-images/app-history.png';
import appHomeImage from '../assets/app-images/app-home.png';
import appInsightsImage from '../assets/app-images/app-insights.png';
import appSettingsImage from '../assets/app-images/app-settings.png';
import appShareImage from '../assets/app-images/app-share.png';
import appSharingSettingsImage from '../assets/app-images/app-sharing-settings.png';

export const site = {
	name: 'MACROS',
	fullName: 'MACROS: Nutrition Tracker',
	tagline: 'Track calories and macros with barcode and label scans, no account.',
	description:
		'MACROS: Nutrition Tracker is a local-first iPhone app for logging calories, protein, carbs, and fat with barcode and nutrition label scanning, fast manual entry, and no account.',
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
		'All food logging, barcode and nutrition label scanning, and online packaged-food search',
		'Saved foods and meals, and history',
		'Small and medium Home Screen widgets and a Lock Screen widget',
		'Daily share card and sharing circle',
		'Goal calculator and basic weight log',
		'Write nutrition to Apple Health',
		'One daily reminder',
	],
	proFeatures: [
		'Insights charts with ranges from 7D to All',
		'Weight trends and weight import from Apple Health',
		'Backup export and import',
		'Custom macro ring colors',
		'Custom widget color and photo backgrounds',
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
			answer: 'Pro adds Insights charts from 7D to All, weight trends, weight import from Apple Health, backup export and import, custom ring colors, custom widget color and photo backgrounds, and multiple or smart reminders.',
		},
		{
			question: 'Does it work offline?',
			answer: 'Your on-device logs and manual entry work offline. Packaged-food search and barcode lookup need a connection.',
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
	// TODO: Replace these cards with the new screenshots when they arrive. Expected files in
	// src/assets/app-images/: app-home.png, app-add-food.png, app-camera.png, app-insights.png,
	// app-history.png, app-settings.png, app-widgets.png, app-paywall.png, app-share.png.
	screenshots: [
		{
			src: appHomeImage,
			alt: 'MACROS daily dashboard with logged meals and filled macro rings',
			title: 'Daily macro rings',
		},
		{
			src: appAddFoodImage,
			alt: 'MACROS add food screen with search, common foods, barcode scan, and label scan actions',
			title: 'Search, scan, or add food',
		},
		{
			src: appSettingsImage,
			alt: 'MACROS settings screen with goals and saved custom foods',
			title: 'Goals and saved foods',
		},
		{
			src: appInsightsImage,
			alt: 'MACROS insights screen with nutrition trends and macro charts',
			title: 'Insights and trends (Pro)',
		},
		{
			src: appHistoryImage,
			alt: 'MACROS history screen with a full week of logged food progress',
			title: 'Weekly history',
		},
		{
			src: appSharingSettingsImage,
			alt: 'MACROS sharing settings screen with invite link controls',
			title: 'Sharing circle',
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
