# Following layout source regression guards

## User Input

Original: “继续处理上一个会话出现的问题 … 切换卡顿，会出现没反应，切换后滑动也卡顿”

English translation: “Continue fixing the prior session's problem: layout switching stutters or becomes unresponsive, and scrolling afterwards also stutters.”

## Change / reason

Added `tests/following-layout/test_structure.py` with seven stdlib unittest guards. They require separate list/grid containers, per-video list rows, a lazy grid and lazy footer, one resize-width calculation outside the card loop, a last-card pagination guard, lazy bounded author strip, persistent preferences and retained refresh/navigation wiring. The optional FOLLOWING_VIEW_SOURCE environment variable supports checking a previous source revision.

## Verification / failures / limits

The seven checks pass on the fixed source. They intentionally reject the old single-List-cell video grid. They check source structure only: they cannot validate compilation, gesture responsiveness, real image request counts, memory, pagination network behavior, or frame pacing. Use native CI and the device checklist in the companion performance log. No extra package dependency was installed.
