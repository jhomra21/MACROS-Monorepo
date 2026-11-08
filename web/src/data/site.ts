import appAddFoodImage from '../assets/app-images/app-add-food.png';
import appHistoryImage from '../assets/app-images/app-history.png';
import appHomeImage from '../assets/app-images/app-home.png';
import appInsightsImage from '../assets/app-images/app-insights.png';
import appScanDetailsImage from '../assets/app-images/app-scan-details.png';
import appScanReviewImage from '../assets/app-images/app-scan-review.png';
import appSettingsImage from '../assets/app-images/app-settings.png';
import appSharingImage from '../assets/app-images/app-sharing.png';
import appSharingPersonImage from '../assets/app-images/app-sharing-person.png';
import appWidgetsImage from '../assets/app-images/app-widgets.png';
import { siteOrigin } from './origin';
import loggingCrop from '../assets/feature-crops/logging.png';
import scanningCrop from '../assets/feature-crops/scanning.png';
import privacyCrop from '../assets/feature-crops/privacy.png';
import portionCrop from '../assets/feature-crops/portion.png';
import sharingCrop from '../assets/feature-crops/sharing.png';
import widgetsCrop from '../assets/feature-crops/widgets.png';

export const site = {
	name: 'MACROS',
	fullName: 'MACROS: Nutrition Tracker',
	lockupSubtitle: 'Nutrition Tracker',
	url: siteOrigin,
	tagline: 'An iPhone food diary. No account needed.',
	description:
		'MACROS is a calorie counter and macro tracker for iPhone. Keep your food diary on your device, scan a label, and get on with your day. No account needed.',
	appStore: { id: '6767565938', live: false },
	instagramURL: 'https://www.instagram.com/macrosios/',
	supportEmail: 'jhonra121@gmail.com',
	navItems: [
		{ href: '/#why', label: 'Why MACROS', secondary: true },
		{ href: '/#plans', label: 'Pro', secondary: true },
		{ href: '/learn/', label: 'Learn', secondary: false },
		{ href: '/about/', label: 'About', secondary: false },
		{ href: '/support/', label: 'Support', secondary: false },
	],
	footerLinks: [
		{
			heading: 'Product',
			links: [
				{ href: '/#why', label: 'Why MACROS' },
				{ href: '/#showcase', label: 'Screenshots' },
				{ href: '/#plans', label: 'MACROS Pro' },
				{ href: '/#faq', label: 'FAQ' },
			],
		},
		{
			heading: 'Company',
			links: [
				{ href: '/learn/', label: 'Learn' },
				{ href: '/guides/', label: 'Macro guides' },
				{ href: '/about/', label: 'About' },
				{ href: '/support/', label: 'Support' },
			],
		},
		{
			heading: 'Legal',
			links: [
				{ href: '/privacy/', label: 'Privacy policy' },
				{ href: '/terms/', label: 'Terms of use' },
			],
		},
	],
	hero: {
		title: 'Log your food. Get on with your day.',
		lead: 'Your calories and macros, at a glance. No account needed.',
	},
	features: [
		{
			image: loggingCrop,
			background: '#f2f2f7',
			alt: 'Daily rings showing 1,310 of 2,200 kcal, 95 g protein, 162 g carbs, and 34 g fat.',
			title: 'Open it and start.',
			body: 'Open the app and start your food diary.',
			size: 'wide',
		},
		{
			image: scanningCrop,
			background: '#000000',
			alt: 'Oat Crunch Cereal scan result: 190 kcal, one 40 g serving, and the Log button.',
			title: 'Scan it instead of typing it.',
			body: 'Scan the barcode or nutrition label on the pack.',
			size: 'narrow',
		},
		{
			image: privacyCrop,
			background: '#f2f2f7',
			alt: 'Four food diary entries: protein bar, chicken and rice bowl, plain Greek yogurt cup, and oatmeal with banana, with calories and macros.',
			title: 'Keep your diary on your phone.',
			body: 'Your food log lives on your iPhone. Sharing is your choice.',
			link: { text: 'Your food log lives on your iPhone', href: '/privacy/' },
			size: 'narrow',
		},
		{
			image: portionCrop,
			background: '#202020',
			alt: 'Scan review showing the Servings stepper set to one, 1 cup (40 g) each, 40 g total, and Edit details and Log buttons.',
			title: 'Half the pack? Make it half.',
			body: 'Check your portion before you log it.',
			size: 'wide',
		},
		{
			image: sharingCrop,
			background: '#f2f2f7',
			alt: 'Sharing list with Alex at 1,650 kcal and Sam at 1,420 kcal, with protein, carbs, and fat totals.',
			title: 'Let someone check in.',
			body: 'Invite someone with Pro, or accept their invite for free.',
			size: 'half',
		},
		{
			image: widgetsCrop,
			background: '#bc976d',
			alt: 'Medium personal MACROS Home Screen widget showing 1,310 kcal, 95 g protein, 162 g carbs, and 34 g fat against the iPhone wallpaper.',
			title: 'A glance before dinner.',
			body: 'See your daily totals without opening the app.',
			size: 'half',
		},
	],
	freeFeatures: [
		'Food logging, search, barcode and label scans',
		'Saved foods, meals, and history',
		'Personal widgets: small, medium, and Lock Screen',
		'Daily share card and accepting invites',
		'Goal calculator and weight log',
		'Nutrition writing to Apple Health',
		'One daily reminder',
	],
	proFeatures: [
		'Insights beyond 7 days',
		'Sending sharing invites',
		'Shared-person widgets: Home Screen and Lock Screen',
		'Weight trends and Apple Health weight import',
		'Backup export and import',
		'Your choice of ring colors',
		'Widget colors and photo backgrounds',
		'Multiple and smart reminders',
	],
	proPrices: [
		{ name: 'Monthly', price: '$2.99', cadence: 'per month', note: 'No free trial' },
		{ name: 'Yearly', price: '$19.99', cadence: 'per year', note: '7-day free trial' },
		{ name: 'Lifetime', price: '$49.99', cadence: 'one time', note: 'No renewals. One purchase per Apple Account.' },
	],
	plansNote: 'Prices and offers vary by region. Apple confirms the price before you buy.',
	faq: [
		{
			question: 'Do I have to sign up?',
			answer: 'No. You can log food without an account. Optional sharing uses a separate profile.',
		},
		{
			question: 'Can I use it for free?',
			answer: 'Yes. Logging, search, barcode and label scans, saved foods, history, personal widgets, and writing nutrition to Apple Health are free. Pro is optional.',
			link: { text: 'Pro is optional', href: '/#plans' },
		},
		{
			question: 'What do I get with Pro?',
			answer: 'Pro adds Insights beyond 7 days, sharing invites, shared-person widgets, weight trends, Apple Health weight import, backup export and import, custom ring colors, widget colors and photo backgrounds, and multiple or smart reminders. Anyone with your invite link can connect and share back for free. Links expire after 7 days unless you revoke them sooner. Connections work while either person has Pro.',
		},
		{
			question: 'What does Pro cost?',
			answer: '$2.99 monthly, $19.99 yearly with a 7-day free trial, or $49.99 for lifetime. Prices vary by region. Apple confirms the price before you buy.',
		},
		{
			question: 'Can I log food offline?',
			answer: 'Yes, for logging, manual entry, and searching foods on your device. Other food searches and barcode lookups need a connection.',
		},
		{
			question: 'Does anything leave my phone?',
			answer: 'Search terms and barcodes go to the MACROS food-search service. Sharing starts off. Turn it on to send your display name, optional goals, and today\'s calories, protein, carbs, fat, and entry count. Choose Nothing, Macros, or Macros + Foods for each person. Shared foods include today\'s names, amounts, and nutrients, never logged times, notes, photos, or barcodes. Foods upload only while someone can see them and are deleted when food sharing stops. Older days are deleted. People see today only.',
			link: { text: 'MACROS food-search service', href: '/privacy/#food-search-and-barcode-lookup' },
		},
	],
	heroShowcase: {
		src: appHomeImage,
		alt: 'MACROS food diary with calorie and macro rings above today\'s meals',
	},
	screenshots: [
		{
			src: appHomeImage,
			alt: 'MACROS dashboard with a full day logged, Food list, macro rings, goals, and streak',
			title: 'Your day so far',
		},
		{
			src: appAddFoodImage,
			alt: 'Food search for greek yogurt with On Device matches and Search Results showing brands beneath food names',
			title: 'Find your usual',
		},
		{
			src: appScanReviewImage,
			alt: 'Oat Crunch Cereal label scan with 190 calories, serving controls, and Edit details and Log buttons in the compact camera card',
			title: 'Check the portion',
		},
		{
			src: appScanDetailsImage,
			alt: 'Oat Crunch Cereal editor expanded inside the camera card with serving fields, a Less button, and Log in the footer',
			title: 'Fix a scan',
		},
		{
			src: appHistoryImage,
			alt: 'History for November 2 with the week selector, daily macro totals, and logged foods',
			title: 'What was lunch yesterday?',
		},
		{
			src: appInsightsImage,
			alt: '30-day Pro Insights with the Weight card aligned with calorie and macro average tiles above the calorie chart',
			title: 'Look back with Pro',
		},
		{
			src: appSharingImage,
			alt: 'Sharing list with Alex and Sam, their daily macro totals, and what each person sees',
			title: 'Check in with your people',
		},
		{
			src: appSharingPersonImage,
			alt: 'Alex’s shared day with macro rings, goals, food entries, and sharing controls',
			title: 'See Alex\'s day',
		},
		{
			src: appWidgetsImage,
			alt: 'iPhone Home Screen with personal small and medium macro widgets and a shared-person widget showing Alex’s macros',
			title: 'Your totals. Alex\'s with Pro.',
		},
		{
			src: appSettingsImage,
			alt: 'Settings showing MACROS Pro, calorie and macro goals, and food suggestions',
			title: 'Set your own goals',
		},
	],
	supportChecklist: [
		'Name the screen or food entry where the problem happened.',
		'Give the email address for our reply.',
		'Say what you expected and what happened instead.',
	],
} as const;
