import addSearchImage from '../assets/app-images/add-search.jpeg';
import calendarClosedLightImage from '../assets/app-images/calendar-closed-light.jpeg';
import calendarOpenImage from '../assets/app-images/calendar-open.jpeg';
import home1Image from '../assets/app-images/home1.jpeg';
import home1LightImage from '../assets/app-images/home1-light.jpeg';
import home2Image from '../assets/app-images/home2.jpeg';

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
	heroShowcase: [
		{
			src: home1LightImage,
			alt: 'Cal Macro Tracker dashboard in light mode',
			label: 'Light mode',
		},
		{
			src: home1Image,
			alt: 'Cal Macro Tracker dashboard in dark mode',
			label: 'Dark mode',
		},
	],
	macroHighlights: [
		{
			label: 'Calories',
			value: '2184',
			tone: 'calories',
		},
		{
			label: 'Protein',
			value: '168g',
			tone: 'protein',
		},
		{
			label: 'Carbs',
			value: '214g',
			tone: 'carbs',
		},
		{
			label: 'Fat',
			value: '72g',
			tone: 'fat',
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
			src: home1LightImage,
			alt: 'Cal Macro Tracker daily summary screen in light mode',
			title: 'Daily summary in light mode',
			body: 'The same dashboard stays clean and readable in bright conditions.',
			theme: 'Light',
		},
		{
			src: home1Image,
			alt: 'Cal Macro Tracker daily summary screen',
			title: 'Daily macro summary',
			body: 'See calories and macro progress at a glance from the main dashboard.',
			theme: 'Dark',
		},
		{
			src: home2Image,
			alt: 'Cal Macro Tracker home screen showing logged meals',
			title: 'Logged meals',
			body: 'Review the meals you have already added for the day without extra clutter.',
			theme: 'Dark',
		},
		{
			src: addSearchImage,
			alt: 'Cal Macro Tracker add food search screen',
			title: 'Add food quickly',
			body: 'Jump into search and logging from a focused entry point built for speed.',
			theme: 'Light',
		},
		{
			src: calendarClosedLightImage,
			alt: 'Cal Macro Tracker calendar view in light mode',
			title: 'Calendar overview',
			body: 'History keeps the current week visible without burying the rest of the day.',
			theme: 'Light',
		},
		{
			src: calendarOpenImage,
			alt: 'Cal Macro Tracker calendar view',
			title: 'Review history',
			body: 'Look back across days to understand consistency and trends.',
			theme: 'Dark',
		},
	],
	supportChecklist: [
		'Share the screen, flow, or food entry that caused the issue.',
		'Include the email address where you want the reply.',
		'Mention what you expected to happen and what happened instead.',
	],
} as const;
