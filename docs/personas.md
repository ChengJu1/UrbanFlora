# UrbanFlora Personas

Three personas drive every screen's design trade-offs. When in doubt, ask:
*"which of the three am I currently annoying?"*

## 1. Li Wei — the curious student

- **Age / role**: 24, CASA MSc student
- **Where they use it**: on campus walks between lectures, Regent's Canal at lunch
- **Primary goal**: turn "what is that flower?" curiosity into a playful record
- **Tech comfort**: high, expects gestures, dark mode, fast shutter
- **Pain points**: boring apps lose them in a week; they want streaks and a codex to fill
- **Key quote**: "If it feels like Pokémon for plants, I'll use it every day."

## 2. Chen Ayi — the mindful walker

- **Age / role**: 58, retired accountant, does a daily loop around the local park
- **Primary goal**: finally remember the names of the plants she passes every day
- **Tech comfort**: moderate — taps, not swipes; dislikes tiny fonts
- **Pain points**: too-clever apps full of jargon; pop-ups she can't dismiss
- **Key quote**: "I don't want a science paper, I want a nickname and a little history."

## 3. Marcus — the data journalist

- **Age / role**: 31, freelance data reporter working on urban-greening stories
- **Primary goal**: contribute to and later query a biodiversity dataset for a neighbourhood
- **Tech comfort**: high, will notice if the API integration is janky
- **Pain points**: apps that silo his data; no way to export or share
- **Key quote**: "If the observations are aggregated on a map I'll keep feeding it."

## Design decisions these personas drove

- **Big shutter button** (Chen Ayi): must be reachable one-handed, no cognitive load.
- **Confidence ring + manual choice** (Marcus): never silently commit an ML guess to his dataset.
- **Rarity & streak system** (Li Wei): quick visual rewards, the "Pokémon for plants" feel.
- **Anonymous sign-in option**: Chen Ayi shouldn't be forced through a Google flow on day one.
- **Firestore-synced profile**: Marcus can log on desktop later (future web build) and still see his data.
