"""Source-structure guards, not a substitute for device performance tests.

Run with Python's stdlib on iOS or CI. FOLLOWING_VIEW_SOURCE can point at a
previous revision to check that these guards reject the old layout.
"""
import os
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(os.environ.get(
    "FOLLOWING_VIEW_SOURCE",
    ROOT / "iosApp/Features/Following/FollowingView.swift",
)).read_text()


def body_of(declaration):
    match = re.search(declaration + r"[^\n]*\{", SOURCE)
    if match is None:
        raise AssertionError(f"Missing declaration: {declaration}")
    start = match.end()
    depth = 1
    # Ignore comments and strings so their braces do not affect nesting.
    token = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|[{}]', re.S)
    for item in token.finditer(SOURCE, start):
        if item.group() == "{":
            depth += 1
        elif item.group() == "}":
            depth -= 1
            if depth == 0:
                return SOURCE[start:item.start()]
    raise AssertionError(f"Unclosed declaration: {declaration}")


class FollowingLayoutStructureTests(unittest.TestCase):
    def test_loaded_state_selects_independent_scroll_containers(self):
        content = body_of(r"private func content\(")
        self.assertIn("if isGridLayout", content)
        self.assertIn("gridContent(snapshot:", content)
        self.assertIn("listContent(snapshot:", content)
        self.assertNotIn("List {", content)
        self.assertIn(".navigationDestination(", content)

    def test_list_keeps_per_video_rows_not_a_video_grid(self):
        content = body_of(r"private func listContent\(")
        self.assertIn("List {", content)
        self.assertIn("ForEach(snapshot.videos)", content)
        self.assertIn("FollowingVideoRowView(video: video)", content)
        self.assertNotIn("LazyVGrid", content)
        self.assertNotIn("gridContent(", content)
        self.assertNotIn("FollowingVideoGridCard", content)

    def test_grid_and_footer_are_in_viewport_lazy_container(self):
        content = body_of(r"private func gridContent\(")
        self.assertIn("return ScrollView {", content)
        self.assertIn("LazyVStack(spacing:", content)
        self.assertIn("LazyVGrid(columns: followingGridColumns", content)
        self.assertIn("ForEach(snapshot.videos)", content)
        self.assertIn("followingFooter(snapshot: snapshot)", content)
        self.assertNotIn("List {", content)
        self.assertNotIn(".listRowInsets", content)
        self.assertNotRegex(content, r"(?<!Lazy)\bVStack\(")

    def test_image_resize_is_computed_once_outside_video_loop(self):
        content = body_of(r"private func gridContent\(")
        self.assertEqual(content.count("followingGridImageResizeWidth("), 1)
        self.assertLess(content.index("let resizeWidth ="), content.index("ForEach(snapshot.videos)"))
        self.assertIn("resizeWidth: resizeWidth", content)

    def test_only_last_grid_card_requests_next_page(self):
        content = body_of(r"private func gridContent\(")
        self.assertIn("if video.id == snapshot.videos.last?.id", content)
        self.assertIn("viewModel.loadMoreIfNeeded(currentItemID: video.id)", content)
        self.assertIn("pushedVideoCode = video.videoCode", content)

    def test_author_strip_is_lazy_and_has_bounded_height(self):
        content = body_of(r"private func artistsContent\(")
        self.assertIn("LazyHStack(spacing:", content)
        self.assertIn(".frame(height:", content)

    def test_existing_preferences_and_refresh_are_preserved(self):
        self.assertIn('@AppStorage("following_updates_layout")', SOURCE)
        self.assertIn('@AppStorage("following_updates_grid_columns")', SOURCE)
        self.assertIn(".refreshable", SOURCE)
        self.assertIn("await viewModel.refresh()", SOURCE)
        header = body_of(r"private var updatesHeader:")
        self.assertIn("Picker(selection: $updatesLayout)", header)
        self.assertNotIn("viewModel.load", header)
        self.assertNotIn("viewModel.refresh", header)


if __name__ == "__main__":
    unittest.main(verbosity=2)
