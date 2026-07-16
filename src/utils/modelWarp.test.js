import { describe, it, expect } from 'vitest';
import {
  imageRows,
  classRowSpans,
  classRuns,
  nearestRunSpan,
  polylineX,
  smoothSpans,
  garmentLegSplit,
  topWarpPlan,
  bottomWarpPlan,
} from './modelWarp';
import { SEG_CLOTHES, SEG_BODY_SKIN } from './bodyAnalysis';

/** Immagine alpha sintetica (capo scontornato): {width,height,data RGBA}. */
const makeAlpha = (w, h, paint) => {
  const data = new Uint8ClampedArray(w * h * 4);
  const setRow = (y, x0, x1) => {
    for (let x = x0; x < x1; x++) data[(y * w + x) * 4 + 3] = 255;
  };
  paint(setRow);
  return { width: w, height: h, data };
};

/** Maschera classi sintetica: {width,height,categories}. */
const makeSeg = (w, h, paint) => {
  const categories = new Uint8Array(w * h);
  const setRow = (y, x0, x1, cls) => {
    for (let x = x0; x < x1; x++) categories[y * w + x] = cls;
  };
  paint(setRow);
  return { width: w, height: h, categories };
};

describe('imageRows', () => {
  it('trova le corse opache per riga', () => {
    const img = makeAlpha(20, 3, (setRow) => {
      setRow(0, 2, 8);
      setRow(1, 2, 8);
      setRow(1, 12, 18);
    });
    const rows = imageRows(img);
    expect(rows[0]).toMatchObject({ left: 2, right: 7 });
    expect(rows[0].runs).toEqual([[2, 8]]);
    expect(rows[1].runs).toEqual([[2, 8], [12, 18]]);
    expect(rows[2]).toBeNull();
  });
});

describe('classRowSpans', () => {
  const seg = makeSeg(20, 4, (setRow) => {
    setRow(0, 4, 14, SEG_CLOTHES);
    setRow(1, 4, 9, SEG_CLOTHES); // corsa sull'asse (10)? no: 4..9 non contiene 10
    setRow(1, 11, 16, SEG_CLOTHES); // questa contiene... 11..16 non contiene 10; la più vicina
    setRow(2, 0, 20, SEG_BODY_SKIN);
  });

  it('per ogni riga prende la corsa della classe che contiene l\'asse', () => {
    const spans = classRowSpans(seg, [SEG_CLOTHES], 10);
    expect(spans[0]).toEqual({ left: 4, right: 13 });
    expect(spans[2]).toBeNull(); // pelle, non vestiti
    expect(spans[3]).toBeNull();
  });

  it('se nessuna corsa contiene l\'asse prende la più vicina', () => {
    const spans = classRowSpans(seg, [SEG_CLOTHES], 10);
    expect(spans[1]).toEqual({ left: 11, right: 15 });
  });

  it('accetta più classi (gambe nude: vestiti O pelle)', () => {
    const spans = classRowSpans(seg, [SEG_CLOTHES, SEG_BODY_SKIN], 10);
    expect(spans[2]).toEqual({ left: 0, right: 19 });
  });
});

describe('classRuns + nearestRunSpan', () => {
  it('tutte le corse per riga, e la più vicina a un punto', () => {
    const seg = makeSeg(20, 1, (setRow) => {
      setRow(0, 2, 6, SEG_CLOTHES);
      setRow(0, 10, 16, SEG_CLOTHES);
    });
    const rows = classRuns(seg, [SEG_CLOTHES]);
    expect(rows[0]).toEqual([[2, 6], [10, 16]]);
    expect(nearestRunSpan(rows[0], 4)).toEqual({ left: 2, right: 5 });
    expect(nearestRunSpan(rows[0], 9)).toEqual({ left: 10, right: 15 });
    expect(nearestRunSpan(null, 9)).toBeNull();
  });
});

describe('polylineX', () => {
  const leg = [
    { x: 100, y: 0 },
    { x: 110, y: 10 },
    { x: 105, y: 20 },
  ];
  it('interpola fra i punti e blocca agli estremi', () => {
    expect(polylineX(leg, -5)).toBe(100);
    expect(polylineX(leg, 5)).toBe(105);
    expect(polylineX(leg, 10)).toBe(110);
    expect(polylineX(leg, 15)).toBe(107.5);
    expect(polylineX(leg, 99)).toBe(105);
  });
});

describe('smoothSpans', () => {
  it('media mobile sui bordi, i buchi restano buchi', () => {
    const spans = [
      { left: 10, right: 20 },
      { left: 12, right: 26 },
      { left: 8, right: 20 },
      null,
      { left: 10, right: 20 },
    ];
    const out = smoothSpans(spans, 1);
    expect(out[1].left).toBe(10); // (10+12+8)/3
    expect(out[1].right).toBe(22); // (20+26+20)/3
    expect(out[3]).toBeNull();
    // il vicino del buco media solo ciò che esiste
    expect(out[4]).toEqual({ left: 10, right: 20 });
  });
});

describe('garmentLegSplit', () => {
  // pantaloni sintetici 40 largo × 30 alto: tronco unito (righe 0..9),
  // due gambe (righe 10..29)
  const pants = makeAlpha(40, 30, (setRow) => {
    for (let y = 0; y < 10; y++) setRow(y, 5, 35);
    for (let y = 10; y < 30; y++) {
      setRow(y, 5, 18);
      setRow(y, 22, 35);
    }
  });

  it('trova la riga del cavallo del capo', () => {
    const split = garmentLegSplit(imageRows(pants), pants.width);
    expect(split.crotchRow).toBe(10);
  });

  it('separa la gamba sinistra e destra per riga', () => {
    const split = garmentLegSplit(imageRows(pants), pants.width);
    expect(split.legL[15]).toEqual([5, 18]);
    expect(split.legR[15]).toEqual([22, 35]);
  });

  it('null se le gambe non si separano mai (gonna)', () => {
    const skirt = makeAlpha(40, 30, (setRow) => {
      for (let y = 0; y < 30; y++) setRow(y, 5, 35);
    });
    expect(garmentLegSplit(imageRows(skirt), skirt.width)).toBeNull();
  });
});

describe('topWarpPlan', () => {
  // capo 10 righe (box.top=0), destinazione dal colletto y=100 all'orlo y=119
  const garmentRows = Array.from({ length: 10 }, (_, y) => ({
    runs: [[0, 20]],
    left: 0,
    right: 19,
  }));
  const destSpans = [];
  for (let y = 100; y < 120; y++) destSpans[y] = { left: 40, right: 59 };

  it('mappa linearmente le righe sorgente e usa gli span di destinazione', () => {
    const plan = topWarpPlan({
      garmentRows,
      garmentBox: { top: 0, bottom: 9 },
      destSpans,
      collarY: 100,
      hemY: 119,
    });
    expect(plan.length).toBe(20);
    expect(plan[0]).toMatchObject({ yd: 100, ys: 0, dx0: 40, dw: 20 });
    expect(plan[19]).toMatchObject({ yd: 119, ys: 9 });
    expect(plan[10].ys).toBe(Math.round((10 / 19) * 9));
    // sorgente: tutta la corsa opaca della riga
    expect(plan[0].sx0).toBe(0);
    expect(plan[0].sw).toBe(20);
  });

  it('le righe strette del capo (colletto) restano proporzionali, centrate', () => {
    // capo con scollo: le prime 2 righe larghe 5 (su 20 di spalla)
    const collared = garmentRows.map((r, y) =>
      y < 2 ? { runs: [[8, 13]], left: 8, right: 12 } : r
    );
    const plan = topWarpPlan({
      garmentRows: collared,
      garmentBox: { top: 0, bottom: 9 },
      destSpans,
      collarY: 100,
      hemY: 119,
      shoulderRefWidth: 20,
    });
    const first = plan.find((r) => r.yd === 100);
    // 5/20 della larghezza di destinazione (20) = 5, centrata su 49.5
    expect(first.dw).toBe(5);
    expect(first.dx0).toBe(47);
    // le righe piene restano a tutta larghezza
    const last = plan.find((r) => r.yd === 119);
    expect(last.dw).toBe(20);
    expect(last.dx0).toBe(40);
  });

  it('le righe di destinazione senza span vengono saltate', () => {
    const holey = [...destSpans];
    holey[110] = null;
    const plan = topWarpPlan({
      garmentRows,
      garmentBox: { top: 0, bottom: 9 },
      destSpans: holey,
      collarY: 100,
      hemY: 119,
    });
    expect(plan.find((r) => r.yd === 110)).toBeUndefined();
  });
});

describe('bottomWarpPlan', () => {
  const pants = makeAlpha(40, 30, (setRow) => {
    for (let y = 0; y < 10; y++) setRow(y, 5, 35);
    for (let y = 10; y < 30; y++) {
      setRow(y, 5, 18);
      setRow(y, 22, 35);
    }
  });
  const garmentRows = imageRows(pants);

  // persona: vita a y=200, cavallo a 220, caviglie a 280
  const trunkSpans = [];
  for (let y = 200; y <= 220; y++) trunkSpans[y] = { left: 90, right: 130 };
  // gambe: colonne per y, con centri che si spostano (ginocchio)
  const legLSpans = [];
  const legRSpans = [];
  for (let y = 220; y <= 280; y++) {
    legLSpans[y] = { left: 88, right: 106 };
    legRSpans[y] = { left: 114, right: 132 };
  }

  it('verticale lineare unica; una corsa→tronco, due corse→una per gamba', () => {
    const plan = bottomWarpPlan({
      garmentRows,
      garmentBox: { top: 0, bottom: 29 },
      legSplit: garmentLegSplit(garmentRows, pants.width),
      waistY: 200,
      crotchY: 220,
      ankleY: 280,
      trunkSpans,
      legLSpans,
      legRSpans,
    });
    // vita: riga singola del capo sul tronco
    expect(plan[0]).toMatchObject({ yd: 200, ys: 0, dx0: 90, dw: 41 });
    // il capo si divide alla SUA riga 10, che con la mappa lineare
    // (80 righe di persona su 29 del capo) cade a yd ≈ 228
    const at228 = plan.filter((r) => r.yd === 228);
    expect(at228).toHaveLength(2);
    const [l, r] = at228.sort((a, b) => a.dx0 - b.dx0);
    expect(l).toMatchObject({ dx0: 88, dw: 19, sx0: 5, sw: 13 });
    expect(r).toMatchObject({ dx0: 114, dw: 19, sx0: 22, sw: 13 });
    // fra il cavallo della persona (220) e la separazione del capo (228)
    // la riga singola copre l'UNIONE delle due gambe
    const single = plan.find((row) => row.yd === 224);
    expect(single).toMatchObject({ dx0: 88, dw: 45 });
    // ultima riga: fondo del capo alle caviglie
    const last = plan[plan.length - 1];
    expect(last.yd).toBe(280);
    expect(last.ys).toBe(29);
  });

  it('riga fusa sotto il cavallo (risvolti che si toccano): metà per gamba', () => {
    // pantaloni con le gambe che si RIUNISCONO nelle ultime righe
    const touching = makeAlpha(40, 30, (setRow) => {
      for (let y = 0; y < 10; y++) setRow(y, 5, 35);
      for (let y = 10; y < 26; y++) {
        setRow(y, 5, 18);
        setRow(y, 22, 35);
      }
      for (let y = 26; y < 30; y++) setRow(y, 5, 35); // risvolti fusi
    });
    const rows = imageRows(touching);
    const plan = bottomWarpPlan({
      garmentRows: rows,
      garmentBox: { top: 0, bottom: 29 },
      legSplit: garmentLegSplit(rows, touching.width),
      waistY: 200,
      crotchY: 220,
      ankleY: 280,
      trunkSpans,
      legLSpans,
      legRSpans,
    });
    // ultima riga (ys=29, fusa): due mezze corse, una per gamba — niente
    // barra unica stirata sull'unione delle gambe
    const last = plan.filter((r) => r.yd === 280);
    expect(last).toHaveLength(2);
    const [l, r] = last.sort((a, b) => a.dx0 - b.dx0);
    expect(l).toMatchObject({ dx0: 88, sx0: 5, sw: 15 });
    expect(r).toMatchObject({ dx0: 114, sx0: 20, sw: 15 });
  });

  it('senza cavallo del capo (gonna): tutto tronco, mai per-gamba', () => {
    const skirtRows = imageRows(
      makeAlpha(40, 30, (setRow) => {
        for (let y = 0; y < 30; y++) setRow(y, 5, 35);
      })
    );
    const allSpans = [];
    for (let y = 200; y <= 280; y++) allSpans[y] = { left: 90, right: 130 };
    const plan = bottomWarpPlan({
      garmentRows: skirtRows,
      garmentBox: { top: 0, bottom: 29 },
      legSplit: null,
      waistY: 200,
      crotchY: 220,
      ankleY: 280,
      trunkSpans: allSpans,
      legLSpans: [],
      legRSpans: [],
    });
    expect(plan[0].yd).toBe(200);
    expect(plan[plan.length - 1].yd).toBe(280);
    expect(plan.every((r) => r.dx0 === 90)).toBe(true);
  });
});
