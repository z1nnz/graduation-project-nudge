"""Write prompts.json: every image prompt for the J1 character sheets.

  python -I tool/character_art/make_prompts.py

Each job is one generated image: a character reference sheet first, then
one strip per animation with that reference attached, so every frame of a
character looks the same. walk_right is mirrored from walk_left.
"""
import json
from pathlib import Path

STYLE = ("16-bit pixel art, cozy fantasy town, warm wood and parchment palette with soft purple night tones, "
         "crisp pixel edges, no anti-aliasing blur, consistent top-down 3/4 view, no text, no logo, no watermark")
KEY = "on a flat pure magenta #FF00FF background, no shadow on the background"
STRIP = ("{n} frames in one horizontal row, evenly spaced with wide magenta gaps between frames, "
         "each frame a full-body chibi character about 2.5 heads tall that fits a 128x128 cell, "
         "feet on the same baseline in every frame, identical design, outfit and colours to the attached reference sheet")

CHARACTERS = {
    "companion": ("the cheerful young adventurer from the attached picture: spiky navy-blue hair with a gold star hair clip, "
                  "brown eyes, white scarf, navy jacket with gold trim, white shirt, brown belt and pouches, "
                  "cream shorts, fur-trimmed brown boots, navy backpack with gold stars"),
    "chestnut": ("a cheerful shopkeeper girl named Chestnut, chestnut-brown bob hair, round glasses, "
                 "brown apron over a cream blouse, rolled sleeves, a small coin pouch at the waist"),
    "scroll": ("a friendly notice-board clerk boy named Scroll, messy sandy hair, ink-stained green vest, "
               "a big rolled parchment scroll carried on his back with a strap, a quill behind one ear"),
    "bounce": ("a lively amusement-park keeper named Bounce, small striped red and yellow clown hat with a pom-pom, "
               "rosy cheeks, big grin, colourful patchwork waistcoat, puffy sleeves, bouncy energetic posture"),
    "sprout": ("a gentle garden keeper girl named Sprout, wide straw hat with a green ribbon, light green overalls, "
               "rubber boots, holding a small copper watering can"),
    "inky": ("a calm librarian named Inky, neat dark purple hair, a single round monocle on a gold chain, "
             "long deep-blue coat with book buttons, holding a thick leather book"),
    "bell": ("a sturdy tower gatekeeper named Bell, short grey beard, warm brown hooded cloak over leather armour, "
             "holding a glowing brass lantern on a short pole"),
    "letty": ("a quick young letter carrier named Letty, red cap with a gold envelope badge, short orange hair, "
              "blue postal jacket, a big brown messenger bag across the body stuffed with letters"),
    "stella": ("a kind old astronomer woman named Stella, long silver hair in a bun, small round spectacles, "
               "a deep violet cloak covered in tiny gold stars, holding a small brass telescope"),
}

NPC_ANIMS = {
    "idle": (4, "idle breathing and blinking animation: chest rises and falls slightly, eyes closed in frame 3, facing the viewer"),
    "talk": (4, "talking animation facing the viewer: mouth opening and closing, small friendly hand gesture"),
    "walk_down": (4, "walking toward the viewer, alternating legs, contact-passing-contact-passing walk cycle"),
    "walk_left": (4, "walking to the left in side view, alternating legs, contact-passing-contact-passing walk cycle"),
    "walk_up": (4, "walking away from the viewer seen from behind, alternating legs, contact-passing-contact-passing walk cycle"),
}
COMPANION_ANIMS = {
    **NPC_ANIMS,
    "happy": (6, "happy jump animation facing the viewer: crouch, jump up with both arms raised and a big smile, peak, fall, land, settle"),
    "wave": (4, "waving hello facing the viewer: one hand raised waving side to side, smiling"),
    "think": (4, "thinking animation facing the viewer: hand on chin, eyes looking up, head tilting slightly"),
    "sleep": (4, "sleeping curled up lying on the floor, eyes closed, gentle breathing, body rising and falling slightly"),
}
COMPANION_ANIMS.pop("talk")


def main():
    jobs = []
    for cid, desc in CHARACTERS.items():
        refs = ["assets/avatar/characters/character_0.png", "assets/avatar/poses/walk_0_a.png"] if cid == "companion" else []
        jobs.append({
            "out": f"{cid}/reference.png",
            "attach": refs,
            "size": "1536x1024",
            "prompt": (f"character reference sheet of {desc}, front side back views standing in a row, full body, "
                       f"16-bit pixel art chibi proportions, {STYLE}, {KEY}"),
        })
        anims = COMPANION_ANIMS if cid == "companion" else NPC_ANIMS
        for name, (n, motion) in anims.items():
            jobs.append({
                "out": f"{cid}/{name}.png",
                "attach": [f"{cid}/reference.png"],
                "size": "1536x1024",
                "prompt": (f"sprite sheet, {n} frames {motion} of the same character: {desc}. "
                           f"{STRIP.format(n=n)}, {STYLE}, {KEY}"),
            })
    out = Path(__file__).with_name("prompts.json")
    out.write_text(json.dumps({"style": STYLE, "key": KEY, "jobs": jobs}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(len(jobs), "jobs ->", out)


if __name__ == "__main__":
    main()
