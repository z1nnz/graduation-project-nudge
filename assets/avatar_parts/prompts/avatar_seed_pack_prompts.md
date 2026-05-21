# Avatar Seed Pack Prompts

Use these prompts when generating replacement art in ChatGPT or another image tool. Every result must be a full-canvas transparent PNG at `512 x 768 px`.

## Global Style

Original cute 2D paper-doll avatar part for a self-discipline app named Nudge. Soft rounded Q-style proportions, polished mobile game asset, clean vector-like illustration, gentle highlights, subtle shading, no outline heavier than 4 px, no text, no watermark. Keep the part aligned to the same full-body canvas: 512 x 768 px, character centered, feet baseline around y 705. Transparent background. Do not crop the canvas.

## Base Body

Create the base body layer only: neck, arms, hands, legs, and soft ground shadow. No head, no hair, no face, no clothing details except neutral hidden body guide shapes. Skin tone: `<skin tone>`. Full 512 x 768 transparent canvas.

Filename: `body_skin_<skinIndex>.png`

## Face

Create the face layer only: rounded Q-style head and ears, no hair, no eyes, no eyebrows, no mouth. Skin tone: `<skin tone>`. Full 512 x 768 transparent canvas.

Filename: `face_<faceIndex>_skin_<skinIndex>.png`

## Hair Back

Create the back hair layer only for hairstyle `<hair style>`, hair color `<hair color>`. It should sit behind the head and neck. No face, no skin, no clothing. Full 512 x 768 transparent canvas.

Filename: `hair_<hairIndex>_color_<hairColorIndex>.png`

## Hair Front

Create the front hair layer only for hairstyle `<hair style>`, hair color `<hair color>`. It should sit over the forehead and partially frame the face. No head base, no eyes, no clothing. Full 512 x 768 transparent canvas.

Filename: `hair_<hairIndex>_color_<hairColorIndex>.png`

## Eyes

Create the eyes layer only: `<eye style>` eyes for a cute Q-style paper-doll avatar. Use dark ink with tiny highlight if appropriate. No head, no eyebrows, no mouth. Full 512 x 768 transparent canvas.

Filename: `eyes_<eyeIndex>.png`

## Eyebrows

Create the eyebrows layer only: `<eyebrow style>` eyebrows. No eyes, no head, no mouth. Full 512 x 768 transparent canvas.

Filename: `eyebrows_<eyebrowIndex>.png`

## Mouth

Create the mouth layer only: `<mouth style>` expression. No head, no eyes. Full 512 x 768 transparent canvas.

Filename: `mouth_<mouthIndex>.png`

## Outfit

Create the outfit layer only: `<outfit style>` with color `<outfit color>`, including top, sleeves, pants/skirt if needed, and shoes. It must align to the same body. No head, no hair, no face. Full 512 x 768 transparent canvas.

Filename: `outfit_<outfitIndex>_color_<outfitColorIndex>.png`

## Accessory

Create the accessory layer only: `<accessory>`, positioned on the character where it naturally belongs. No character body, no head, no background. Full 512 x 768 transparent canvas.

Filename: `accessory_<accessoryIndex>.png`

## Background

Create a soft character display background for Nudge. Pastel rounded gradient, subtle stars or study-room mood, no text, no logo, no character. Full 512 x 768 PNG. It can be opaque or softly translucent.

Filename: `background_<backgroundIndex>.png`
