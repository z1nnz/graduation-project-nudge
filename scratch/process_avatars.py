from PIL import Image

def process_character(src_path, dest_char_path, dest_icon_path):
    img = Image.open(src_path)
    
    # 1. Resize character to 1024x1536
    char_img = img.resize((1024, 1536), Image.Resampling.LANCZOS)
    char_img.save(dest_char_path, 'PNG')
    print(f"Saved character to {dest_char_path}")
    
    # 2. Crop face region centered at x=512, y=420
    # Box size: 600x600
    crop_box = (212, 120, 812, 720)
    face_img = char_img.crop(crop_box).resize((1254, 1254), Image.Resampling.LANCZOS)
    face_img.save(dest_icon_path, 'PNG')
    print(f"Saved icon to {dest_icon_path}")

# Process Character 9 (Apprentice)
process_character(
    '/Users/whzi_111/.gemini/antigravity/brain/ffc941f1-8ab8-47f2-a32e-60e3a1717cfa/media__1779944935523.png',
    'assets/avatar/characters/character_9.png',
    'assets/avatar/icons/icon_9.png'
)

# Process Character 11 (Guardian)
process_character(
    '/Users/whzi_111/.gemini/antigravity/brain/ffc941f1-8ab8-47f2-a32e-60e3a1717cfa/media__1779945358789.png',
    'assets/avatar/characters/character_11.png',
    'assets/avatar/icons/icon_11.png'
)
