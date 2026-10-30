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
	url: 'https://macros-web.jhonra121.workers.dev',
	tagline: 'Track calories and macros with barcode and label scans, no account.',
	description:
		'MACROS: Nutrition Tracker is a local-first iPhone app for logging calories, protein, carbs, and fat with barcode and nutrition label scanning, fast manual entry, and no account.',
	// Set this to the App Store listing URL at launch. The header and hero show a download button only when it is non-empty.
	appStoreURL: '',
	supportEmail: 'jhonra121@gmail.com',
	ogImage: {
		src: '/og.png',
		alt: 'MACROS: Nutrition Tracker on an iPhone showing daily protein, carbs, and fat rings',
		width: 1200,
		height: 630,
	},
	navItems: [
		{ href: '/#why', label: 'Why MACROS', secondary: true },
		{ href: '/#plans', label: 'Pro', secondary: true },
		{ href: '/about', label: 'About', secondary: false },
		{ href: '/support', label: 'Support', secondary: false },
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
				{ href: '/about', label: 'About' },
				{ href: '/support', label: 'Support' },
			],
		},
		{
			heading: 'Legal',
			links: [
				{ href: '/privacy', label: 'Privacy policy' },
				{ href: '/terms', label: 'Terms of use' },
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
			body: 'Invite people with Pro and they see your daily totals. Anyone you invite shares back for free. Sharing individual foods and more stats is coming.',
			size: 'half',
		},
		{
			eyebrow: 'Widgets',
			glyph: 'widget',
			accent: 'fat',
			title: 'Widgets and Apple Health.',
			body: 'Home Screen and Lock Screen widgets. Nutrition goes to Apple Health if you allow it.',
			size: 'half',
		},
	],
	freeFeatures: [
		'All food logging, barcode and nutrition label scanning, and online packaged-food search',
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
			answer: 'Yes. Food logging, barcode and nutrition label scanning, saved foods, history, widgets, and Apple Health writing are free. MACROS Pro is optional.',
		},
		{
			question: 'What is MACROS Pro?',
			answer: 'Pro adds Insights ranges beyond 7 days, sharing circle invites, weight trends, weight import from Apple Health, backup export and import, custom ring colors, custom widget color and photo backgrounds, and multiple or smart reminders. Anyone a Pro user invites can accept and share back for free.',
		},
		{
			question: 'How much does Pro cost?',
			answer: '$2.99 per month, $19.99 per year with a 7-day free trial, or $49.99 once for lifetime. Prices vary by region. Apple shows the price before you buy.',
		},
		{
			question: 'Does it work offline?',
			answer: 'Logging and manual entry work offline. Packaged-food search and barcode lookup need a connection.',
		},
		{
			question: 'What leaves my phone?',
			answer: 'Search terms or barcodes go to our food-search service. If you turn on sharing, this version sends your chosen display name and daily nutrition totals to the people you invite. Individual foods are not sent yet.',
		},
	],
	heroShowcase: {
		src: appHomeImage,
		alt: 'MACROS dashboard with a full day of food logged',
	},
	// TODO: Replace these cards with the new captures when they arrive. Drop files with these exact
	// names into src/assets/app-images/ and update the imports below; no component changes needed:
	// app-home.png, app-add-food.png, app-camera.png, app-insights.png, app-history.png,
	// app-settings.png, app-widgets.png, app-paywall.png, app-share.png.
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
		'Name the screen or food entry where the problem happened.',
		'Give the email address for our reply.',
		'Say what you expected and what happened instead.',
	],
} as const;
