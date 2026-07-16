import { useEffect, useMemo, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { garmentLayers } from '../../utils/tryonComposer';
import { loadGarmentTexture } from '../../utils/garmentImage';
import {
  loadPersonCutout,
  analyzePersonImage,
  trimmedGarment,
  imageAspect,
  buildWarpedLayers,
} from '../../utils/modelImage';
import { garmentPlacements } from '../../utils/modelComposer';
import './Avatar.css';

/**
 * "Su modello": la persona della foto di riferimento, scontornata (@imgly,
 * on-device, gratis) e vestita con le foto vere dei capi — anch'esse
 * scontornate — scalate sulle SUE proporzioni (spalle, fianchi, cavallo,
 * caviglie lette dalla silhouette). Nessuna AI generativa, nessun costo.
 */
export default function ModelTryOn({ outfit, referencePhoto, height = 480 }) {
  const { t } = useTranslation();

  // Persona: scontorno → landmark. status: loading | ready | no-figure | error
  const [personState, setPersonState] = useState({ status: 'loading' });

  useEffect(() => {
    let cancelled = false;
    setPersonState({ status: 'loading' });
    (async () => {
      try {
        const cutoutUrl = await loadPersonCutout(referencePhoto);
        const analyzed = await analyzePersonImage(cutoutUrl);
        if (cancelled) return;
        if (!analyzed) {
          setPersonState({ status: 'no-figure' });
          return;
        }
        setPersonState({ status: 'ready', cutoutUrl, ...analyzed });
      } catch {
        if (!cancelled) setPersonState({ status: 'error' });
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [referencePhoto]);

  // Capi: scontorno (cache IndexedDB dentro loadGarmentTexture) + ritaglio al
  // contenuto. Cache per id: cambiando outfit si prepara solo il capo nuovo.
  const layers = garmentLayers(outfit || {});
  const assetCacheRef = useRef(new Map());
  const [assets, setAssets] = useState({});
  const [garmentsLoading, setGarmentsLoading] = useState(false);
  const itemsKey = layers.map((l) => l.item.id).join(',');

  useEffect(() => {
    let cancelled = false;
    const cache = assetCacheRef.current;
    const pending = layers.filter((l) => !cache.has(l.item.id));
    if (pending.length > 0) setGarmentsLoading(true);

    const prepare = async ({ item }) => {
      const texture = await loadGarmentTexture(item);
      const trimmed = texture.textureUrl ? await trimmedGarment(texture.textureUrl) : null;
      if (trimmed) return trimmed;
      // Ripiego senza scontorno (foto CORS): la foto intera, col suo rapporto.
      try {
        return { url: item.photo, aspect: await imageAspect(item.photo) };
      } catch {
        return null;
      }
    };

    Promise.all(pending.map((l) => prepare(l).then((a) => cache.set(l.item.id, a)))).then(() => {
      if (cancelled) return;
      const next = {};
      for (const { kind, item } of layers) next[kind] = cache.get(item.id);
      setAssets(next);
      setGarmentsLoading(false);
    });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [itemsKey]);

  // Livelli warpati (segmentazione vestiti + posa, on-device): il capo segue
  // riga per riga la sagoma vestita e le gambe vere. Se i modelli ML non
  // caricano si resta sui rettangoli classici (placements qui sotto).
  const [warped, setWarped] = useState(null);
  const [warping, setWarping] = useState(false);
  const assetsKey = Object.entries(assets)
    .map(([k, a]) => `${k}:${a ? a.url.length : 0}`)
    .join(',');

  useEffect(() => {
    let cancelled = false;
    if (personState.status !== 'ready' || Object.keys(assets).length === 0) {
      setWarped(null);
      setWarping(false);
      return undefined;
    }
    setWarping(true);
    buildWarpedLayers({
      photo: referencePhoto,
      cutoutUrl: personState.cutoutUrl,
      person: personState.person,
      assets,
    })
      .then((w) => {
        if (cancelled) return;
        setWarped(w);
        setWarping(false);
      })
      .catch(() => {
        if (cancelled) return;
        setWarped(null);
        setWarping(false);
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [personState, assetsKey, referencePhoto]);

  // Rettangoli di posa nelle coordinate della foto della persona.
  const placements = useMemo(() => {
    if (personState.status !== 'ready') return [];
    const spec = {};
    if (assets.top) spec.top = { aspect: assets.top.aspect };
    if (assets.dress) spec.top = { aspect: assets.dress.aspect, isDress: true };
    if (assets.bottom) spec.bottom = { aspect: assets.bottom.aspect };
    if (assets.outerwear) spec.outerwear = { aspect: assets.outerwear.aspect };
    if (assets.shoes) spec.shoes = { aspect: assets.shoes.aspect };
    return garmentPlacements(personState.person, spec);
  }, [personState, assets]);

  if (personState.status === 'loading') {
    return <p className="model-tryon__status sv-label">{t('tryon.modelPreparingPhoto')}</p>;
  }
  if (personState.status === 'no-figure' || personState.status === 'error') {
    return (
      <p className="model-tryon__status sv-label">
        {t(personState.status === 'no-figure' ? 'tryon.modelNoFigure' : 'tryon.modelError')}
      </p>
    );
  }

  const { person, cutoutUrl, width: natW, height: natH } = personState;
  const pad = person.box.height * 0.05;
  const vb = {
    x: person.box.left - pad,
    y: person.box.top - pad,
    w: person.box.width + pad * 2,
    h: person.box.height + pad * 2,
  };

  return (
    <div className="model-tryon">
      <svg
        viewBox={`${vb.x} ${vb.y} ${vb.w} ${vb.h}`}
        style={{ height }}
        role="img"
        aria-label={t('tryon.modeModel')}
      >
        <defs>
          <linearGradient id="model-bg" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#F5F0E8" />
            <stop offset="100%" stopColor="#EAE2D5" />
          </linearGradient>
        </defs>
        <rect x={vb.x} y={vb.y} width={vb.w} height={vb.h} fill="url(#model-bg)" />
        {/* ombra a terra, come sul manichino 3D */}
        <ellipse
          cx={person.cx}
          cy={person.box.bottom + pad * 0.35}
          rx={person.box.width * 0.55}
          ry={pad * 0.5}
          fill="rgba(26, 26, 26, 0.10)"
        />
        <image href={cutoutUrl} x="0" y="0" width={natW} height={natH} />
        {warped ? (
          <>
            {warped.layers.map((l) => (
              <image key={l.kind} href={l.url} x="0" y="0" width={natW} height={natH} />
            ))}
            {warped.shoes.map((p, i) => (
              <image
                key={`shoes-${i}`}
                href={assets.shoes?.url}
                x={p.x}
                y={p.y}
                width={p.width}
                height={p.height}
                preserveAspectRatio="none"
              />
            ))}
          </>
        ) : (
          !warping &&
          placements.map((p, i) => {
            const asset = assets[p.kind] || (p.kind === 'dress' ? assets.dress : null);
            if (!asset) return null;
            return (
              <image
                key={`${p.kind}-${i}`}
                href={asset.url}
                x={p.x}
                y={p.y}
                width={p.width}
                height={p.height}
                preserveAspectRatio="none"
              />
            );
          })
        )}
      </svg>
      {(garmentsLoading || warping) && (
        <p className="tryon__preparing sv-label">{t('avatar.preparingGarments')}</p>
      )}
    </div>
  );
}
