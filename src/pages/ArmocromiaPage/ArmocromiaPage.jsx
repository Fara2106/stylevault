import { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useProfile } from '../../context/ProfileContext';
import { useWardrobe } from '../../context/WardrobeContext';
import { Header, Button, Icon } from '../../components/common';
import { analyzeFaceColors } from '../../utils/faceColorAnalysis';
import { classifySeason } from '../../utils/armocromiaClassifier';
import { getSeason } from '../../utils/armocromiaSeasons';
import { buildShopLinks } from '../../utils/shopLinks';
import { matchWardrobe } from '../../utils/armocromiaWardrobe';
import { resizeImageFile } from '../../utils/imageUtils';
import './ArmocromiaPage.css';

/**
 * Armocromia: foto → colori personali (correggibili) → stagione → palette,
 * outfit con link shop, capi del guardaroba in palette, make-up.
 * Analisi on-device (faceColorAnalysis); qui solo orchestrazione e UI.
 */
export default function ArmocromiaPage() {
  const { t, i18n } = useTranslation();
  const navigate = useNavigate();
  const { referencePhoto, armocromia, setArmocromia } = useProfile();
  const { items } = useWardrobe();
  const lang = i18n.language?.startsWith('en') ? 'en' : 'it';
  const fileInputRef = useRef(null);

  // fase: idle | analyzing | detected | result
  const [phase, setPhase] = useState(armocromia ? 'result' : 'idle');
  const [detected, setDetected] = useState(
    armocromia?.detected || { skin: null, hair: null, eyes: null }
  );
  const [confidence, setConfidence] = useState(armocromia?.confidence ?? null);
  const [failed, setFailed] = useState(false);
  const [verdict, setVerdict] = useState(armocromia || null);
  const [savedNow, setSavedNow] = useState(false);

  const analyze = async (photoUrl) => {
    setPhase('analyzing');
    setFailed(false);
    const res = await analyzeFaceColors(photoUrl);
    if (res) {
      setDetected({ skin: res.skin, hair: res.hair, eyes: res.eyes });
      setConfidence(res.confidence);
    } else {
      setDetected({ skin: null, hair: null, eyes: null });
      setConfidence(null);
      setFailed(true);
    }
    setPhase('detected');
  };

  const handleUpload = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    try {
      const dataUrl = await resizeImageFile(file, 1024, 0.85);
      analyze(dataUrl);
    } catch {
      setFailed(true);
      setPhase('detected');
    }
  };

  const compute = () => {
    const r = classifySeason(detected);
    if (!r) return;
    setVerdict({
      season: r.season,
      detected,
      axes: r.axes,
      confidence: r.confidence,
      updatedAt: new Date().toISOString(),
    });
    setSavedNow(false);
    setPhase('result');
  };

  const season = verdict ? getSeason(verdict.season) : null;
  const wardrobeMatches = season ? matchWardrobe(items, season.id) : [];

  // Tre combo outfit dalla palette: [colore, neutro, neutro/colore]
  const outfits = season
    ? [
        [season.palette[0], season.neutrals[0], season.neutrals[1]],
        [season.palette[1], season.palette[3], season.neutrals[0]],
        [season.palette[2], season.neutrals[2] || season.neutrals[0], season.palette[4]],
      ]
    : [];
  const outfitParts = [t('armocromia.ui.outfitTop'), t('armocromia.ui.outfitBottom'), t('armocromia.ui.outfitShoes')];

  const swatchRow = (colors) => (
    <div className="armocromia__swatches">
      {colors.map((c) => (
        <span key={c.nameKey + c.hex} className="armocromia__swatch" title={t(c.nameKey)}>
          <i style={{ backgroundColor: c.hex }} />
          <small>{t(c.nameKey)}</small>
        </span>
      ))}
    </div>
  );

  const shopRow = (kind, query) => (
    <span className="armocromia__shops">
      {buildShopLinks({ kind, query, lang }).map((l) => (
        <a key={l.shop} href={l.url} target="_blank" rel="noopener">
          <Icon name="external" size={11} /> {l.label}
        </a>
      ))}
    </span>
  );

  return (
    <div className="sv-page armocromia">
      <Header title={t('armocromia.ui.title')} onBack={() => navigate(-1)} />

      {phase === 'idle' && (
        <section className="armocromia__intro">
          <p>{t('armocromia.ui.intro')}</p>
          <p className="sv-label">{t('armocromia.ui.photoHint')}</p>
          {referencePhoto && (
            <Button fullWidth onClick={() => analyze(referencePhoto)}>
              {t('armocromia.ui.usePhoto')}
            </Button>
          )}
          <Button
            fullWidth
            variant="secondary"
            icon={<Icon name="camera" size={15} />}
            onClick={() => fileInputRef.current?.click()}
          >
            {t('armocromia.ui.uploadPhoto')}
          </Button>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            hidden
            onChange={handleUpload}
          />
        </section>
      )}

      {phase === 'analyzing' && (
        <p className="armocromia__status sv-label">{t('armocromia.ui.analyzing')}</p>
      )}

      {(phase === 'detected' || phase === 'result') && (
        <section className="armocromia__detected">
          <h3 className="sv-label">{t('armocromia.ui.detectedTitle')}</h3>
          {failed && <p className="armocromia__failed">{t('armocromia.ui.analysisFailed')}</p>}
          <div className="armocromia__pickers">
            {['skin', 'hair', 'eyes'].map((part) => (
              <label key={part} className="armocromia__picker">
                <input
                  type="color"
                  value={detected[part] || '#888888'}
                  onChange={(e) => {
                    setDetected((prev) => ({ ...prev, [part]: e.target.value }));
                    setPhase('detected');
                  }}
                />
                <i style={{ backgroundColor: detected[part] || 'transparent' }} />
                <span className="sv-label">{t(`armocromia.ui.${part}`)}</span>
                {!detected[part] && <small>{t('armocromia.ui.missingColor')}</small>}
              </label>
            ))}
          </div>
          {phase === 'detected' && (
            <>
              <Button fullWidth onClick={compute} disabled={!detected.skin && !detected.hair}>
                {t('armocromia.ui.compute')}
              </Button>
              {!detected.skin && !detected.hair && (
                <p className="sv-label">{t('armocromia.ui.needTwo')}</p>
              )}
            </>
          )}
        </section>
      )}

      {phase === 'result' && season && (
        <section className="armocromia__result">
          <div className="armocromia__verdict">
            <h2>{t(season.nameKey)}</h2>
            <p>{t(season.descKey)}</p>
            <p className="sv-label">
              {t('armocromia.ui.confidence')}: {Math.round((verdict.confidence ?? 0) * 100)}%
              {' — '}{t(`armocromia.undertone.${season.makeup.foundationUndertone}`)}
            </p>
            {(verdict.confidence ?? 0) < 0.25 && (
              <p className="armocromia__failed">{t('armocromia.ui.confidenceLow')}</p>
            )}
          </div>

          <h3 className="sv-label">{t('armocromia.ui.paletteTitle')}</h3>
          {swatchRow(season.palette)}
          <h3 className="sv-label">{t('armocromia.ui.neutralsTitle')}</h3>
          {swatchRow(season.neutrals)}
          <h3 className="sv-label">{t('armocromia.ui.avoidTitle')}</h3>
          {swatchRow(season.avoid)}
          <p className="armocromia__metal sv-label">
            {t('armocromia.ui.metalTitle')}: <strong>{t(`armocromia.metal.${season.metal}`)}</strong>
          </p>

          <h3 className="sv-label">{t('armocromia.ui.outfitsTitle')}</h3>
          <div className="armocromia__outfits">
            {outfits.map((combo, i) => (
              <div key={i} className="armocromia__outfit">
                {combo.map((c, j) => (
                  <div key={j} className="armocromia__outfit-item">
                    <i style={{ backgroundColor: c.hex }} />
                    <span>{t(c.nameKey)} — {outfitParts[j]}</span>
                    {shopRow('clothing', `${outfitParts[j]} ${t(c.nameKey)}`)}
                  </div>
                ))}
              </div>
            ))}
          </div>

          <h3 className="sv-label">{t('armocromia.ui.wardrobeTitle')}</h3>
          {wardrobeMatches.length === 0 ? (
            <p className="sv-label">{t('armocromia.ui.wardrobeEmpty')}</p>
          ) : (
            <ul className="armocromia__wardrobe">
              {wardrobeMatches.slice(0, 8).map(({ item, paletteHex }) => (
                <li key={item.id}>
                  {item.photo && <img src={item.photo} alt={item.name} />}
                  <span>{item.name}</span>
                  <i style={{ backgroundColor: paletteHex }} />
                </li>
              ))}
            </ul>
          )}

          <h3 className="sv-label">{t('armocromia.ui.makeupTitle')}</h3>
          <div className="armocromia__makeup">
            {[
              ['lips', season.makeup.lips, t('armocromia.ui.lipstick')],
              ['blush', season.makeup.blush, t('armocromia.ui.blushQuery')],
              ['eyeshadow', season.makeup.eyes, t('armocromia.ui.eyeshadowQuery')],
            ].map(([key, colors, productQuery]) => (
              <div key={key} className="armocromia__makeup-row">
                <span className="sv-label">{t(`armocromia.ui.${key}`)}</span>
                {swatchRow(colors)}
                {shopRow('makeup', `${productQuery} ${t(colors[0].nameKey)}`)}
              </div>
            ))}
            <p className="sv-label">
              {t('armocromia.ui.foundation')}: {t(`armocromia.undertone.${season.makeup.foundationUndertone}`)}
            </p>
          </div>

          <div className="armocromia__actions">
            <Button
              fullWidth
              icon={<Icon name={savedNow ? 'check' : 'heart'} size={15} />}
              onClick={() => { setArmocromia(verdict); setSavedNow(true); }}
              disabled={savedNow}
            >
              {savedNow ? t('armocromia.ui.saved') : t('armocromia.ui.save')}
            </Button>
            <Button fullWidth variant="secondary" icon={<Icon name="refresh" size={14} />}
              onClick={() => { setPhase('idle'); setVerdict(null); }}>
              {t('armocromia.ui.redo')}
            </Button>
          </div>
        </section>
      )}
    </div>
  );
}
