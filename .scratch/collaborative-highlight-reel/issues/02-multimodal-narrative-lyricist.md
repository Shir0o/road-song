# 02: Trip Narrative Extraction & Rhyming Lyricist Engine

**What to build:** 
The app processes all collected media evidence and text notes in a session, clusters them into a chronological narrative arc (Beginning/Intro $\rightarrow$ Rising Chaos $\rightarrow$ Peak Climax $\rightarrow$ Outro), and prompts Gemini to produce structured rhyming lyrics with explicit participant name-drops, section tags (`[Verse]`, `[Chorus]`, etc.), and syllable timing estimates.

**Blocked by:** 01: Collaborative Session Creation & Frictionless Media Drop

**Status:** ready-for-agent

- [ ] Narrative clustering service grouping session evidence chronologically and thematically.
- [ ] Prompt orchestrator formatting media summaries and text evidence for the LLM.
- [ ] Structured JSON output parser validating rhyming lyrics, musical sections, and participant callouts.
- [ ] Fallback generator for sparse evidence sessions.
- [ ] Test coverage $\ge 90\%$ for narrative extractor and lyricist parser.
