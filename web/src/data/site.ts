export const site = {
	name: 'Cal Macro Tracker',
	tagline: 'Track calories and macros without creating an account.',
	description:
		'Cal Macro Tracker is a local-first iPhone app for logging calories, protein, carbs, and fat with barcode scans, nutrition label photos, and fast manual entry.',
	navItems: [
		{ href: '/', label: 'Home' },
		{ href: '/about', label: 'About' },
		{ href: '/privacy', label: 'Privacy' },
		{ href: '/support', label: 'Support' },
	],
	features: [
		{
			title: 'Local-first by default',
			body: 'Your food log is designed around on-device storage so you can track without creating an account first.',
		},
		{
			title: 'Fast capture flows',
			body: 'Log food with barcode scan, nutrition label photo, or manual search and entry when you need a fallback.',
		},
		{
			title: 'Macro clarity',
			body: 'Review calories, protein, carbs, and fat with a simple daily summary built for quick decisions.',
		},
	],
	flows: [
		'Scan a barcode for packaged foods.',
		'Capture a nutrition label photo for a label-first workflow.',
		'Use manual search or manual entry when the database or label is incomplete.',
		'Review serving size and quantity before logging.',
	],
	screenshots: [
		{
			src: '/app-images/home1.jpeg',
			alt: 'Cal Macro Tracker daily summary screen',
			title: 'Daily macro summary',
			body: 'See calories and macro progress at a glance from the main dashboard.',
		},
		{
			src: '/app-images/home2.jpeg',
			alt: 'Cal Macro Tracker home screen showing logged meals',
			title: 'Logged meals',
			body: 'Review the meals you have already added for the day without extra clutter.',
		},
		{
			src: '/app-images/add-search.jpeg',
			alt: 'Cal Macro Tracker add food search screen',
			title: 'Add food quickly',
			body: 'Jump into search and logging from a focused entry point built for speed.',
		},
		{
			src: '/app-images/calendar-open.jpeg',
			alt: 'Cal Macro Tracker calendar view',
			title: 'Review history',
			body: 'Look back across days to understand consistency and trends.',
		},
	],
	supportChecklist: [
		'Share the screen, flow, or food entry that caused the issue.',
		'Include the email address where you want the reply.',
		'Mention what you expected to happen and what happened instead.',
	],
} as const;
