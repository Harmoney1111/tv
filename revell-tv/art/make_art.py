#!/usr/bin/env python3
"""Draws the Revell T.V artwork: wallpaper, logo, home-screen icons and splash screen.

    python3 art/make_art.py

Writes the image files in images/. Change the colours or the text here and run it again.
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps

IMAGES = Path(__file__).resolve().parent.parent / "images"
FONTS = Path("/usr/share/fonts/opentype/inter")
WORDMARK = str(FONTS / "InterDisplay-BlackItalic.otf")
LABEL = str(FONTS / "InterDisplay-ExtraBold.otf")

PINK, VIOLET, CYAN, ORANGE = (255, 46, 147), (122, 43, 255), (0, 212, 255), (255, 138, 0)
NIGHT = (10, 8, 28)


def gradient(size, start, middle, end, angle):
    """A three-colour gradient running across the picture at `angle` degrees."""
    width, height = size
    side = int((width ** 2 + height ** 2) ** 0.5) + 2
    ramp = Image.linear_gradient("L").resize((side, side)).rotate(angle + 90, resample=Image.BICUBIC)
    left, top = (side - width) // 2, (side - height) // 2
    ramp = ramp.crop((left, top, left + width, top + height))
    return ImageOps.colorize(ramp, black=start, white=end, mid=middle)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def centred(draw, box, text, font, fill):
    """Draw text centred in box = (left, top, right, bottom)."""
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    x = box[0] + (box[2] - box[0] - (right - left)) / 2 - left
    y = box[1] + (box[3] - box[1] - (bottom - top)) / 2 - top
    draw.text((x, y), text, font=font, fill=fill)


def wallpaper():
    """Dark night sky with soft glows of colour, kept dim enough to read text over."""
    width, height = 1280, 720
    small = Image.new("RGB", (width // 4, height // 4), NIGHT)
    glows = [  # x, y, radius, colour, strength (quarter-size coordinates)
        (20, 175, 115, PINK, 0.70),
        (150, 0, 120, VIOLET, 0.75),
        (305, 150, 95, CYAN, 0.50),
        (290, 10, 48, ORANGE, 0.40),
    ]
    for x, y, radius, colour, strength in glows:
        layer = Image.new("RGB", small.size, (0, 0, 0))
        tint = tuple(int(channel * strength) for channel in colour)
        ImageDraw.Draw(layer).ellipse([x - radius, y - radius, x + radius, y + radius], fill=tint)
        small = ImageChops.screen(small, layer.filter(ImageFilter.GaussianBlur(radius * 0.5)))
    image = small.resize((width, height), Image.BICUBIC).filter(ImageFilter.GaussianBlur(8))

    # A few faint light streaks, then film grain so the glows do not band.
    streaks = Image.new("RGB", (width, height), (0, 0, 0))
    draw = ImageDraw.Draw(streaks)
    for offset, colour in ((0, CYAN), (70, PINK), (150, VIOLET)):
        draw.line([(780 + offset, -20), (1320 + offset, 420)], fill=tuple(c // 5 for c in colour), width=3)
    image = ImageChops.screen(image, streaks.filter(ImageFilter.GaussianBlur(1.5)))
    grain = Image.effect_noise((width, height), 5).convert("RGB")
    return ImageChops.add(image, grain, 1, -128)


def logo(height):
    """Play badge, the Revell wordmark and a T.V pill, on a transparent background."""
    scale = 2 * height / 72  # drawn double size, then shrunk for smooth edges
    unit = lambda value: int(round(value * scale))
    word_font = ImageFont.truetype(WORDMARK, unit(60))
    pill_font = ImageFont.truetype(LABEL, unit(27))
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    word_box = probe.textbbox((0, 0), "Revell", font=word_font)
    pill_box = probe.textbbox((0, 0), "T.V", font=pill_font)

    badge = unit(72)
    gap = unit(16)
    word_width = word_box[2] - word_box[0]
    pill_size = (pill_box[2] - pill_box[0] + unit(34), unit(42))
    width = badge + gap + word_width + gap + pill_size[0] + unit(4)
    image = Image.new("RGBA", (width, badge), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    image.paste(gradient((badge, badge), PINK, VIOLET, CYAN, 45), (0, 0), rounded_mask((badge, badge), unit(20)))
    middle, reach = badge / 2, badge * 0.23
    draw.polygon([(middle - reach * 0.75, middle - reach), (middle - reach * 0.75, middle + reach), (middle + reach, middle)], fill="white")

    left = badge + gap
    centred(draw, (left, 0, left + word_width, badge), "Revell", word_font, "white")

    left += word_width + gap
    top = (badge - pill_size[1]) // 2
    image.paste(gradient(pill_size, CYAN, VIOLET, PINK, 0), (left, top), rounded_mask(pill_size, pill_size[1] // 2))
    centred(draw, (left, top, left + pill_size[0], top + pill_size[1]), "T.V", pill_font, "white")

    return image.resize((width // 2, badge // 2), Image.LANCZOS)


def icon(size):
    """Home-screen tile: bright gradient, big wordmark, white T.V pill."""
    width, height = size[0] * 2, size[1] * 2
    image = gradient((width, height), PINK, VIOLET, CYAN, 35).convert("RGBA")

    shade = Image.new("L", (width, height), 0)
    ImageDraw.Draw(shade).ellipse([-width * 0.35, height * 0.45, width * 0.75, height * 1.7], fill=120)
    image = Image.composite(Image.new("RGBA", (width, height), (24, 6, 64, 255)), image, shade.filter(ImageFilter.GaussianBlur(width * 0.1)))

    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    ImageDraw.Draw(overlay).polygon([(width * 0.60, height * 0.06), (width * 0.60, height * 0.94), (width * 1.04, height * 0.5)], fill=(255, 255, 255, 40))
    image = Image.alpha_composite(image, overlay)

    word_font = ImageFont.truetype(WORDMARK, int(height * 0.36))
    pill_font = ImageFont.truetype(LABEL, int(height * 0.15))
    word_area = (0, int(height * 0.16), width, int(height * 0.58))

    shadow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    centred(ImageDraw.Draw(shadow), (word_area[0], word_area[1] + int(height * 0.03), word_area[2], word_area[3] + int(height * 0.03)), "Revell", word_font, (20, 0, 50, 150))
    image = Image.alpha_composite(image, shadow.filter(ImageFilter.GaussianBlur(height * 0.025)))

    draw = ImageDraw.Draw(image)
    centred(draw, word_area, "Revell", word_font, "white")
    pill = (int(width * 0.34), int(height * 0.64), int(width * 0.66), int(height * 0.86))
    draw.rounded_rectangle(pill, radius=(pill[3] - pill[1]) // 2, fill="white")
    centred(draw, pill, "T.V", pill_font, VIOLET)

    return image.resize(size, Image.LANCZOS).convert("RGB")


def splash(background):
    image = background.convert("RGBA")
    mark = logo(150)
    image.alpha_composite(mark, ((image.width - mark.width) // 2, (image.height - mark.height) // 2))
    return image.convert("RGB")


def main():
    IMAGES.mkdir(exist_ok=True)
    background = wallpaper()
    background.save(IMAGES / "wallpaper.jpg", quality=90)
    splash(background).save(IMAGES / "splash_hd.jpg", quality=90)
    logo(64).save(IMAGES / "logo.png", optimize=True)
    icon((290, 218)).save(IMAGES / "icon_hd.png", optimize=True)
    icon((540, 405)).save(IMAGES / "icon_fhd.png", optimize=True)
    for path in sorted(IMAGES.iterdir()):
        print(f"{path.stat().st_size:>8} bytes  {path.name}")


if __name__ == "__main__":
    main()
