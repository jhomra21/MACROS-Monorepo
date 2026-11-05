# Macro ring evidence

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/web-rings/about-1440-dark.jpg`.

Section rings are **2.25rem square**, small beside the headline and aligned to the heading grid. At 390px and 1440px they stay legible without competing with the title.

The header logo randomizes its fills in its existing early inline script. A second one-line inline script randomizes every section ring independently after the page markup loads. Section rings draw only when their `[data-reveal]` heading reveals; the PageHeading ring draws on load. Both animations are disabled for reduced motion, leaving the randomized final ring values visible. Browser media emulation confirmed the section-ring animation name is `none` with reduced motion enabled.

The JPEGs show home, about, support, privacy, and the macro-goals guide at 390px and 1440px in light and dark mode. The two PNG closeups show a section heading and the header logo. All captures are under 3 MB. Two consecutive home reloads produced different section fill triples (`55, 58, 77` and `58, 26, 78`).

Mobile Lighthouse: home and about both score 100 in Performance, Accessibility, Best Practices, and SEO. Social-image hash verification passed unchanged.
