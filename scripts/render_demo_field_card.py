"""Render the four-page paper card; requires ReportLab and fontTools locally."""
import argparse
import hashlib
import json
import tempfile
from pathlib import Path
from xml.sax.saxutils import escape
from fontTools.ttLib import TTFont as Font
from fontTools.varLib.instancer import instantiateVariableFont
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, KeepTogether


def render(content, font_file, output):
    data = json.loads(content.read_text())
    if len(data['pages']) != 4:
        raise ValueError('Expected four explicitly planned pages')
    original = Font(font_file)
    used = ''.join([data['status'], data['date'], 'NUDGE 1234 / 準備版 實機未驗 第頁'] +
        [p['title'] + p['kicker'] + ''.join(s['title'] + ''.join(s['lines']) for s in p['sections']) for p in data['pages']])
    missing = set(map(ord, used)) - set(original.getBestCmap())
    if missing:
        raise ValueError('Missing glyphs: ' + ','.join(hex(c) for c in sorted(missing)))
    font = instantiateVariableFont(original, {'wght': 400}, inplace=True)
    with tempfile.TemporaryDirectory(prefix='nudge-card-font-') as tmp:
        static = Path(tmp) / 'NudgeCard-Regular.ttf'
        font.save(static)
        pdfmetrics.registerFont(TTFont('NudgeCard', str(static)))
        styles = {
            'kicker': ParagraphStyle('k', fontName='NudgeCard', fontSize=9, leading=13, textColor=colors.HexColor('#6850B5'), spaceAfter=6),
            'title': ParagraphStyle('t', fontName='NudgeCard', fontSize=22, leading=30, textColor=colors.HexColor('#17243B'), spaceAfter=12),
            'section': ParagraphStyle('s', fontName='NudgeCard', fontSize=12, leading=17, textColor=colors.HexColor('#5438A2'), spaceBefore=10, spaceAfter=5),
            'body': ParagraphStyle('b', fontName='NudgeCard', fontSize=10.5, leading=16, textColor=colors.HexColor('#23344A'), wordWrap='CJK', spaceAfter=5),
            'status': ParagraphStyle('status', fontName='NudgeCard', fontSize=9, leading=14, textColor=colors.HexColor('#864B13'), backColor=colors.HexColor('#FFF1D8'), borderPadding=7, spaceAfter=10),
        }
        story = []
        for index, page in enumerate(data['pages']):
            if index:
                story.append(PageBreak())
            story += [Paragraph(escape(page['kicker']), styles['kicker']), Paragraph(escape(page['title']), styles['title']),
                Paragraph(escape(data['status']), styles['status'])]
            for s in page['sections']:
                group = [Paragraph(escape(s['title']), styles['section'])]
                group += [Paragraph(escape(line), styles['body']) for line in s['lines']]
                story.append(KeepTogether(group))
        def furniture(canvas, doc):
            width, height = A4
            canvas.saveState()
            canvas.setFillColor(colors.HexColor('#8B69FF'))
            canvas.rect(0, height - 9, width, 9, fill=1, stroke=0)
            canvas.setFont('NudgeCard', 9)
            canvas.setFillColor(colors.HexColor('#5A6C82'))
            canvas.drawString(42, height - 31, 'NUDGE / 競賽 Demo 操作卡')
            canvas.setStrokeColor(colors.HexColor('#DBE1EB'))
            canvas.line(42, 35, width - 42, 35)
            canvas.drawString(42, 21, data['date'] + ' / 準備版，實機未驗')
            canvas.drawRightString(width - 42, 21, str(doc.page) + ' / 4')
            canvas.restoreState()
        output.parent.mkdir(parents=True, exist_ok=True)
        doc = SimpleDocTemplate(str(output), pagesize=A4, leftMargin=42, rightMargin=42,
            topMargin=52, bottomMargin=47, title='Nudge 競賽 Demo 操作卡 - 準備版', author='Nudge project',
            pageCompression=1)
        doc.build(story, onFirstPage=furniture, onLaterPages=furniture)
    print(json.dumps({'file': output.name, 'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
        'physical_verified': False}, ensure_ascii=False))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--content', type=Path, required=True)
    p.add_argument('--font', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    render(a.content, a.font, a.out)
