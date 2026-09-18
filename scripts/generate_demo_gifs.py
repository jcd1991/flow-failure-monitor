"""Generate lightweight, self-contained README demo GIFs.

These are visual storyboards of the real portfolio path. They avoid embedding
org URLs or record data while making the safety gates easy to understand.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "media"
W, H = 1200, 720
BG = (9, 18, 38)
INK = (237, 244, 255)
MUTED = (155, 175, 205)
BLUE = (74, 157, 255)
CYAN = (53, 211, 193)
AMBER = (255, 190, 74)
RED = (255, 102, 118)
PANEL = (20, 34, 61)


def font(size: int, bold: bool = False):
    candidates = (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold
        else "/System/Library/Fonts/Supplemental/Arial.ttf",
    )
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def rounded(draw, box, fill, outline=None, radius=18, width=2):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def base(title, kicker, step, total):
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    # Subtle top glow and grid lines.
    d.rectangle((0, 0, W, 7), fill=BLUE)
    for x in range(0, W, 80):
        d.line((x, 0, x, H), fill=(14, 28, 52), width=1)
    for y in range(80, H, 80):
        d.line((0, y, W, y), fill=(14, 28, 52), width=1)
    d.text((62, 48), "FLOW FAILURE MONITOR", font=font(22, True), fill=CYAN)
    d.text((62, 88), title, font=font(44, True), fill=INK)
    d.text((64, 148), kicker, font=font(21), fill=MUTED)
    d.text((1060, 58), f"{step}/{total}", font=font(22, True), fill=AMBER)
    d.line((64, 196, 1136, 196), fill=(49, 72, 106), width=2)
    return im, d


def pill(d, xy, text, fill, text_fill=BG):
    x, y = xy
    box = d.textbbox((0, 0), text, font=font(17, True))
    w, h = box[2] - box[0] + 28, box[3] - box[1] + 16
    rounded(d, (x, y, x + w, y + h), fill, radius=18)
    d.text((x + 14, y + 8), text, font=font(17, True), fill=text_fill)


def footer(d, label, color=CYAN):
    d.text((64, 665), label, font=font(18, True), fill=color)
    d.text((1138, 665), "portfolio demo", font=font(16), fill=MUTED, anchor="ra")


def detection_frames():
    frames = []
    states = [
        ("A Flow fault becomes a structured event", "Fault path → capture → fingerprint", "Fault connector", RED),
        ("The monitor groups the same failure", "Recurring errors become one investigation queue", "Grouped fingerprint", AMBER),
        ("An admin sees the context that matters", "Flow, element, message, record, and next checks", "Investigate", BLUE),
        ("A resolution path is selected deliberately", "Only configured actions appear in the dashboard", "Approved action", CYAN),
    ]
    for i, (title, kicker, label, color) in enumerate(states, 1):
        im, d = base(title, kicker, i, len(states))
        # Left event rail.
        rounded(d, (70, 250, 530, 590), PANEL, outline=(49, 72, 106), width=2)
        d.text((104, 282), "Failure group", font=font(19, True), fill=MUTED)
        d.text((104, 322), "FFM_DemoOrderFlow", font=font(27, True), fill=INK)
        d.text((104, 368), "ValidateOrder", font=font(20), fill=BLUE)
        d.text((104, 414), "missing fulfillment address", font=font(19), fill=RED)
        pill(d, (104, 480), label, color, BG if color != AMBER else BG)
        # Right visual pipeline.
        nodes = [(665, 300, "CAPTURE", CYAN), (835, 300, "GROUP", BLUE), (1005, 300, "REVIEW", AMBER)]
        for j, (x, y, text, node_color) in enumerate(nodes):
            rounded(d, (x, y, x + 120, y + 76), (25, 45, 78), outline=node_color, width=3, radius=15)
            d.text((x + 60, y + 38), text, font=font(16, True), fill=INK, anchor="mm")
            if j < len(nodes) - 1:
                d.line((x + 122, y + 38, x + 162, y + 38), fill=MUTED, width=3)
                d.polygon([(x + 162, y + 38), (x + 151, y + 30), (x + 151, y + 46)], fill=MUTED)
        d.text((665, 440), "2 occurrences  ·  1 fingerprint  ·  Status: New", font=font(19), fill=MUTED)
        footer(d, "OBSERVE WITH CONTEXT", color)
        frames.extend([im] * 8)
    return frames


def recovery_frames():
    frames = []
    states = [
        ("Start with a dry-run", "No business change. Count eligible and skipped records.", "DRY-RUN", BLUE),
        ("Review the safety result", "A stale or invalid record is skipped before the Flow runs.", "GUARDRAIL", AMBER),
        ("Approve one explicit action", "The admin approves the named recovery Flow—not a replay.", "APPROVAL", CYAN),
        ("Execute and audit", "The allowlisted Flow runs asynchronously with per-record results.", "AUDITED", CYAN),
    ]
    for i, (title, kicker, label, color) in enumerate(states, 1):
        im, d = base(title, kicker, i, len(states))
        rounded(d, (70, 254, 1130, 580), PANEL, outline=(49, 72, 106), width=2)
        d.text((110, 292), "Recovery action", font=font(19, True), fill=MUTED)
        d.text((110, 332), "Demo order repair (approved Flow)", font=font(27, True), fill=INK)
        d.text((110, 386), "FFM_DemoOrderRecovery", font=font(20), fill=CYAN)
        pill(d, (110, 440), label, color)
        # Progress / outcome panel.
        rounded(d, (650, 292, 1085, 510), (13, 27, 51), outline=color, width=2, radius=16)
        if i == 1:
            d.text((690, 330), "Eligible", font=font(18), fill=MUTED)
            d.text((690, 365), "1", font=font(44, True), fill=INK)
            d.text((840, 330), "Skipped", font=font(18), fill=MUTED)
            d.text((840, 365), "0", font=font(44, True), fill=INK)
            d.text((690, 455), "Simulation only", font=font(20, True), fill=BLUE)
        elif i == 2:
            d.text((690, 330), "Invalid record", font=font(18), fill=MUTED)
            d.text((690, 372), "Flow not executed", font=font(28, True), fill=AMBER)
            d.text((690, 455), "No matching Account", font=font(20), fill=RED)
        elif i == 3:
            d.text((690, 330), "Approval", font=font(18), fill=MUTED)
            d.text((690, 372), "Explicit + allowlisted", font=font(26, True), fill=CYAN)
            d.text((690, 455), "No generic replay", font=font(20), fill=AMBER)
        else:
            d.text((690, 330), "Result", font=font(18), fill=MUTED)
            d.text((690, 372), "Completed", font=font(29, True), fill=CYAN)
            d.text((690, 455), "Audit: RJ-00024", font=font(20), fill=INK)
        footer(d, "RECOVER WITH GUARDRAILS", color)
        frames.extend([im] * 8)
    return frames


def save(name, frames):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=850, loop=0, optimize=True)
    print(f"{path} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    save("ffm-detect-investigate.gif", detection_frames())
    save("ffm-safe-recovery.gif", recovery_frames())
