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

export const site = {
	name: 'MACROS',
	fullName: 'MACROS: Nutrition Tracker',
	url: 'https://macros-web.jhonra121.workers.dev',
	tagline: 'Track calories and macros with barcode and label scans, no account.',
	description:
		'Track calories and macros on iPhone with MACROS, a food diary with barcode and nutrition label scanners. Log meals on your device with no account required.',
	appStore: { id: '6767565938', live: false },
	author: 'Juan Ramon Martinez Bulnes',
	supportEmail: 'jhonra121@gmail.com',
	navItems: [
		{ href: '/#why', label: 'Why MACROS', secondary: true },
		{ href: '/#plans', label: 'Pro', secondary: true },
		{ href: '/guides/', label: 'Guides', secondary: false },
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
		title: 'Calories and macros, without the account.',
		lead: 'Scan a barcode or nutrition label, review the numbers, and watch your day fill three rings. Your food log stays on your iPhone.',
	},
	features: [
		{
			eyebrow: 'Logging',
			glyph: 'rings',
			accent: 'protein',
			title: 'No account. Open it and log.',
			body: 'Nothing to sign up for. Logging works as soon as the app opens. Sharing is optional.',
			size: 'wide',
		},
		{
			eyebrow: 'Scanning',
			glyph: 'scan',
			accent: 'carbs',
			title: 'Scan a barcode or a nutrition label.',
			body: 'One camera view reads both. If a scan misses, type the food in.',
			size: 'narrow',
		},
		{
			eyebrow: 'Privacy',
			glyph: 'device',
			accent: 'fat',
			title: 'Your food log stays on your iPhone.',
			body: 'Logs, saved foods, goals, and weight entries are stored on your iPhone, not on our servers.',
			size: 'narrow',
		},
		{
			eyebrow: 'Accuracy',
			glyph: 'review',
			accent: 'protein',
			title: 'Review before it counts.',
			body: 'Check serving size, quantity, calories, protein, carbs, and fat before an entry joins your day.',
			size: 'wide',
		},
		{
			eyebrow: 'Sharing',
			glyph: 'people',
			accent: 'carbs',
			title: 'Share your day with your people.',
			body: 'Sharing is optional and off by default. Invite people with Pro, then choose Nothing, Macros, or Macros + Foods for each person. Connections work while either person has Pro. With Pro, add a widget for someone who shares with you.',
			size: 'half',
		},
		{
			eyebrow: 'Widgets',
			glyph: 'widget',
			accent: 'fat',
			title: 'Widgets and Apple Health.',
			body: 'See your macros on your Home Screen or Lock Screen. With Pro, follow someone who shares with you in a widget. Nutrition goes to Apple Health if you allow it.',
			size: 'half',
		},
	],
	freeFeatures: [
		'All food logging, food search, and barcode and nutrition label scanning',
		'Saved foods and meals, and history',
		'Small and medium Home Screen widgets and a Lock Screen widget',
		'Daily share card, and accepting sharing circle invites',
		'Goal calculator and basic weight log',
		'Write nutrition to Apple Health',
		'One daily reminder',
	],
	proFeatures: [
		'Insights ranges beyond 7 days',
		'Sharing circle invites',
		'Shared-person Home Screen and Lock Screen widgets',
		'Weight trends and weight import from Apple Health',
		'Backup export and import',
		'Custom macro ring colors',
		'Custom widget color and photo backgrounds',
		'Multiple and smart reminders',
	],
	plans: [
		{
			id: 'free',
			name: 'Free',
			price: '$0',
			cadence: 'forever',
			badge: '',
			summary: 'Everything you need to log every day.',
			highlights: ['Barcode and label scanning', 'Saved foods, meals, and history', 'Widgets and Apple Health writing'],
			featured: false,
		},
		{
			id: 'pro-yearly',
			name: 'MACROS Pro',
			price: '$19.99',
			cadence: 'per year',
			badge: '7-day free trial',
			summary: 'Adds longer insight ranges, sharing invites, weight trends, and backup. Also $2.99 per month, with no trial.',
			highlights: ['Insights ranges beyond 7 days', 'Sharing circle invites', 'Weight trends, backup, and smart reminders'],
			featured: true,
		},
		{
			id: 'pro-lifetime',
			name: 'Pro Lifetime',
			price: '$49.99',
			cadence: 'one time',
			badge: '',
			summary: 'Every Pro feature for one payment. It never renews.',
			highlights: ['All MACROS Pro features', 'No subscription', 'One purchase per Apple Account'],
			featured: false,
		},
	],
	plansNote: 'Apple shows the price before you buy, and prices and offers can vary by region.',
	faq: [
		{
			question: 'Do I need an account?',
			answer: 'No. Food logging works without an account. Sharing is optional and uses a separate sharing profile.',
		},
		{
			question: 'Is MACROS free?',
			answer: 'Yes. Food logging, food search, barcode and nutrition label scanning, saved foods, history, personal widgets, and Apple Health writing are free. MACROS Pro is optional.',
		},
		{
			question: 'What is MACROS Pro?',
			answer: 'Pro adds Insights ranges beyond 7 days, sharing circle invites, shared-person widgets, weight trends, weight import from Apple Health, backup export and import, custom ring colors, custom widget color and photo backgrounds, and multiple or smart reminders. Anyone with your invite link can connect and share back for free until it expires after 7 days or you revoke it.',
		},
		{
			question: 'How much does Pro cost?',
			answer: '$2.99 per month, $19.99 per year with a 7-day free trial, or $49.99 once for lifetime. Prices vary by region. Apple shows the price before you buy.',
		},
		{
			question: 'Does it work offline?',
			answer: 'Logging, manual entry, and searching on-device foods work offline. Other food search results and barcode lookup need a connection.',
		},
		{
			question: 'What leaves my phone?',
			answer: 'Search terms or barcodes go to our food-search service. Sharing is optional and off by default. When on, the app sends your display name, optional daily goals, and today’s calories, protein, carbs, fat, and entry count; for each person, choose Nothing, Macros, or Macros + Foods. Food sharing includes today’s food names, amounts, calories, protein, carbs, and fat, but never logged times, notes, photos, or barcodes. Foods are uploaded only while at least one person can see them; foods are deleted when sharing them stops, and older days are deleted. Viewers see today only.',
		},
	],
	heroShowcase: {
		src: appHomeImage,
		alt: 'MACROS dashboard with a full day logged, macro goals, and a centered streak',
	},
	screenshots: [
		{
			src: appHomeImage,
			alt: 'MACROS dashboard with a full day logged, Food list, macro rings, goals, and streak',
			title: 'Today’s food and macros',
		},
		{
			src: appAddFoodImage,
			alt: 'Food search for greek yogurt with On Device matches and Search Results showing brands beneath food names',
			title: 'Search foods in one list',
		},
		{
			src: appScanReviewImage,
			alt: 'Oat Crunch Cereal label scan with 190 calories, serving controls, and Edit details and Log buttons in the compact camera card',
			title: 'Review a label scan',
		},
		{
			src: appScanDetailsImage,
			alt: 'Oat Crunch Cereal editor expanded inside the camera card with serving fields, a Less button, and Log in the footer',
			title: 'Edit details in the camera',
		},
		{
			src: appHistoryImage,
			alt: 'History for November 2 with the week selector, daily macro totals, and logged foods',
			title: 'Daily history',
		},
		{
			src: appInsightsImage,
			alt: '30-day Pro Insights with the Weight card aligned with calorie and macro average tiles above the calorie chart',
			title: 'Weight and nutrition trends (Pro)',
		},
		{
			src: appSharingImage,
			alt: 'Sharing list with Alex and Sam, their daily macro totals, and what each person sees',
			title: 'Share with your people',
		},
		{
			src: appSharingPersonImage,
			alt: 'Alex’s shared day with macro rings, goals, food entries, and sharing controls',
			title: 'What Alex shares',
		},
		{
			src: appWidgetsImage,
			alt: 'iPhone Home Screen with personal small and medium macro widgets and a shared-person widget showing Alex’s macros',
			title: 'Your macros and Alex’s (Pro)',
		},
		{
			src: appSettingsImage,
			alt: 'Settings showing MACROS Pro, calorie and macro goals, and food suggestions',
			title: 'Settings and goals',
		},
	],
	supportChecklist: [
		'Name the screen or food entry where the problem happened.',
		'Give the email address for our reply.',
		'Say what you expected and what happened instead.',
	],
} as const;
