import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { useAuth } from './AuthContext';
import { isSupabaseEnabled } from '../services/supabaseClient';
import * as db from '../services/db';

const WardrobeContext = createContext(null);

// localStorage keys (modalità locale / cache offline)
const KEYS = {
  items: 'sv_items',
  outfitHistory: 'sv_outfit_history',
  wishlist: 'sv_wishlist',
  savedOutfits: 'sv_saved_outfits',
  customCategories: 'sv_custom_categories',
};

const cloudCacheKey = (userId) => `sv_cloud_cache_${userId}`;

/** Sample wardrobe items loaded on first run (solo sviluppo, modalità locale) */
const SAMPLE_ITEMS = [
  {
    id: '1',
    name: 'T-shirt Bianca Basic',
    category: 'tops',
    subcategory: 'tshirt',
    brand: 'Zara',
    size: 'M',
    colors: ['white'],
    season: 'all',
    occasion: 'casual',
    warmthLevel: 1,
    photo: 'https://picsum.photos/seed/tshirt1/400/400',
    favorite: true,
    dateAdded: '2025-06-01',
  },
  {
    id: '2',
    name: 'Jeans Slim Scuro',
    category: 'bottoms',
    subcategory: 'jeans',
    brand: "Levi's",
    size: '32',
    colors: ['denim'],
    season: 'all',
    occasion: 'casual',
    warmthLevel: 2,
    photo: 'https://picsum.photos/seed/jeans1/400/400',
    favorite: false,
    dateAdded: '2025-06-02',
  },
  {
    id: '3',
    name: 'Blazer Navy',
    category: 'outerwear',
    subcategory: 'blazer',
    brand: 'Hugo Boss',
    size: '48',
    colors: ['navy'],
    season: 'autumn',
    occasion: 'formal',
    warmthLevel: 3,
    photo: 'https://picsum.photos/seed/blazer1/400/400',
    favorite: true,
    dateAdded: '2025-06-03',
  },
  {
    id: '4',
    name: 'Sneakers Bianche',
    category: 'shoes',
    subcategory: 'sneakers',
    brand: 'Nike',
    size: '43',
    colors: ['white'],
    season: 'all',
    occasion: 'casual',
    warmthLevel: 1,
    photo: 'https://picsum.photos/seed/sneakers1/400/400',
    favorite: false,
    dateAdded: '2025-06-04',
  },
  {
    id: '5',
    name: 'Camicia Celeste',
    category: 'tops',
    subcategory: 'shirt',
    brand: 'Ralph Lauren',
    size: 'M',
    colors: ['lightblue'],
    season: 'all',
    occasion: 'business',
    warmthLevel: 2,
    photo: 'https://picsum.photos/seed/shirt1/400/400',
    favorite: false,
    dateAdded: '2025-06-05',
  },
  {
    id: '6',
    name: 'Piumino Nero',
    category: 'outerwear',
    subcategory: 'puffer',
    brand: 'Moncler',
    size: 'M',
    colors: ['black'],
    season: 'winter',
    occasion: 'casual',
    warmthLevel: 5,
    photo: 'https://picsum.photos/seed/puffer1/400/400',
    favorite: true,
    dateAdded: '2025-06-06',
  },
  {
    id: '7',
    name: 'Pantaloni Eleganti Grigi',
    category: 'bottoms',
    subcategory: 'trousers',
    brand: 'Armani',
    size: '48',
    colors: ['gray'],
    season: 'all',
    occasion: 'formal',
    warmthLevel: 2,
    photo: 'https://picsum.photos/seed/trousers1/400/400',
    favorite: false,
    dateAdded: '2025-06-07',
  },
  {
    id: '8',
    name: 'Felpa Oversize Beige',
    category: 'tops',
    subcategory: 'hoodie',
    brand: 'COS',
    size: 'L',
    colors: ['beige'],
    season: 'autumn',
    occasion: 'casual',
    warmthLevel: 3,
    photo: 'https://picsum.photos/seed/hoodie1/400/400',
    favorite: false,
    dateAdded: '2025-06-08',
  },
  {
    id: '9',
    name: 'Stivali Chelsea',
    category: 'shoes',
    subcategory: 'boots',
    brand: 'Dr. Martens',
    size: '43',
    colors: ['black'],
    season: 'winter',
    occasion: 'casual',
    warmthLevel: 3,
    photo: 'https://picsum.photos/seed/boots1/400/400',
    favorite: false,
    dateAdded: '2025-06-09',
  },
  {
    id: '10',
    name: 'Occhiali da Sole',
    category: 'accessories',
    subcategory: 'sunglasses',
    brand: 'Ray-Ban',
    size: '',
    colors: ['black', 'gold'],
    season: 'summer',
    occasion: 'casual',
    warmthLevel: 0,
    photo: 'https://picsum.photos/seed/sunglasses1/400/400',
    favorite: true,
    dateAdded: '2025-06-10',
  },
];

function loadFromStorage(key, fallback) {
  try {
    const stored = localStorage.getItem(key);
    if (stored) return JSON.parse(stored);
  } catch (e) {
    console.warn(`Failed to load ${key} from localStorage:`, e);
  }
  return fallback;
}

function saveToStorage(key, data) {
  try {
    localStorage.setItem(key, JSON.stringify(data));
  } catch (e) {
    console.warn(`Failed to save ${key} to localStorage:`, e);
  }
}

const tempId = (prefix) =>
  `${prefix}_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

/** Le scritture cloud non bloccano la UI: fallimento → warn (i dati restano locali). */
function fireCloud(promise) {
  promise?.catch((e) => console.warn('Cloud sync failed:', e));
}

/**
 * WardrobeProvider — guardaroba, wishlist, outfit salvati, storico/calendario.
 * Modalità locale: tutto in localStorage (Fase A).
 * Modalità cloud: Supabase con aggiornamenti ottimistici e cache di lettura offline.
 */
export function WardrobeProvider({ children }) {
  const { user } = useAuth();
  const userId = user?.id;

  const [items, setItems] = useState(() => {
    if (isSupabaseEnabled) return [];
    const stored = loadFromStorage(KEYS.items, null);
    if (stored !== null) return stored;
    // Dati di esempio solo in sviluppo; in produzione si parte dal guardaroba vuoto
    return import.meta.env.DEV ? SAMPLE_ITEMS : [];
  });
  const [outfitHistory, setOutfitHistory] = useState(() =>
    isSupabaseEnabled ? [] : loadFromStorage(KEYS.outfitHistory, [])
  );
  const [wishlist, setWishlist] = useState(() =>
    isSupabaseEnabled ? [] : loadFromStorage(KEYS.wishlist, [])
  );
  const [savedOutfits, setSavedOutfits] = useState(() =>
    isSupabaseEnabled ? [] : loadFromStorage(KEYS.savedOutfits, [])
  );
  const [customCategories, setCustomCategories] = useState(() =>
    loadFromStorage(KEYS.customCategories, [])
  );
  const [isSyncing, setIsSyncing] = useState(isSupabaseEnabled);

  // ── Caricamento iniziale dal cloud (con cache offline in lettura) ──
  useEffect(() => {
    if (!isSupabaseEnabled) return;
    if (!userId) {
      setItems([]);
      setWishlist([]);
      setSavedOutfits([]);
      setOutfitHistory([]);
      setIsSyncing(false);
      return;
    }
    let alive = true;
    setIsSyncing(true);
    db.fetchAllData(userId)
      .then((data) => {
        if (!alive) return;
        setItems(data.items);
        setWishlist(data.wishlist);
        setSavedOutfits(data.savedOutfits);
        setOutfitHistory(data.outfitHistory);
        saveToStorage(cloudCacheKey(userId), data);
      })
      .catch((e) => {
        console.warn('Cloud load failed, using offline cache:', e);
        if (!alive) return;
        const cached = loadFromStorage(cloudCacheKey(userId), null);
        if (cached) {
          setItems(cached.items || []);
          setWishlist(cached.wishlist || []);
          setSavedOutfits(cached.savedOutfits || []);
          setOutfitHistory(cached.outfitHistory || []);
        }
      })
      .finally(() => alive && setIsSyncing(false));
    return () => {
      alive = false;
    };
  }, [userId]);

  // ── Persistenza locale (Fase A) ──
  useEffect(() => {
    if (!isSupabaseEnabled) saveToStorage(KEYS.items, items);
  }, [items]);
  useEffect(() => {
    if (!isSupabaseEnabled) saveToStorage(KEYS.outfitHistory, outfitHistory);
  }, [outfitHistory]);
  useEffect(() => {
    if (!isSupabaseEnabled) saveToStorage(KEYS.wishlist, wishlist);
  }, [wishlist]);
  useEffect(() => {
    if (!isSupabaseEnabled) saveToStorage(KEYS.savedOutfits, savedOutfits);
  }, [savedOutfits]);
  useEffect(() => {
    saveToStorage(KEYS.customCategories, customCategories);
  }, [customCategories]);

  // ── Item CRUD ──

  const addItem = useCallback(
    (item) => {
      const newItem = {
        ...item,
        id: item.id || tempId('item'),
        dateAdded: item.dateAdded || new Date().toISOString().split('T')[0],
        favorite: item.favorite || false,
      };
      setItems((prev) => [...prev, newItem]);

      if (isSupabaseEnabled && userId) {
        fireCloud(
          db.insertItem(newItem, userId).then((saved) => {
            setItems((prev) => prev.map((i) => (i.id === newItem.id ? saved : i)));
          })
        );
      }
      return newItem;
    },
    [userId]
  );

  const removeItem = useCallback(
    (id) => {
      setItems((prev) => {
        const target = prev.find((i) => i.id === id);
        if (isSupabaseEnabled && target) {
          fireCloud(db.deleteItemRow(id, target.photoPath));
        }
        return prev.filter((item) => item.id !== id);
      });
    },
    []
  );

  const updateItem = useCallback(
    (id, updates) => {
      setItems((prev) =>
        prev.map((item) => (item.id === id ? { ...item, ...updates } : item))
      );
      if (isSupabaseEnabled && userId) {
        fireCloud(
          db.updateItemRow(id, updates, userId).then((signedPhoto) => {
            if (signedPhoto) {
              setItems((prev) =>
                prev.map((i) => (i.id === id ? { ...i, photo: signedPhoto } : i))
              );
            }
          })
        );
      }
    },
    [userId]
  );

  const toggleFavorite = useCallback((id) => {
    setItems((prev) =>
      prev.map((item) => {
        if (item.id !== id) return item;
        const favorite = !item.favorite;
        if (isSupabaseEnabled) fireCloud(db.setFavorite(id, favorite));
        return { ...item, favorite };
      })
    );
  }, []);

  // ── Outfit History (calendario: worn=false → pianificato) ──

  const logOutfit = useCallback(
    (outfit, date, { worn = true } = {}) => {
      const log = {
        id: tempId('log'),
        outfit,
        date: date || new Date().toISOString().split('T')[0],
        worn,
        timestamp: Date.now(),
      };
      setOutfitHistory((prev) => [log, ...prev]);

      if (isSupabaseEnabled && userId) {
        fireCloud(
          db.insertCalendarEntry(outfit, log.date, worn, userId).then((saved) => {
            setOutfitHistory((prev) =>
              prev.map((l) => (l.id === log.id ? { ...l, ...saved } : l))
            );
          })
        );
      }
      return log;
    },
    [userId]
  );

  const updateOutfitLog = useCallback((id, updates) => {
    setOutfitHistory((prev) =>
      prev.map((log) => (log.id === id ? { ...log, ...updates } : log))
    );
    if (isSupabaseEnabled) fireCloud(db.updateCalendarEntry(id, updates));
  }, []);

  const removeOutfitLog = useCallback((id) => {
    setOutfitHistory((prev) => prev.filter((log) => log.id !== id));
    if (isSupabaseEnabled) fireCloud(db.deleteCalendarEntry(id));
  }, []);

  // ── Saved Outfits ──

  const saveOutfit = useCallback(
    (outfit) => {
      const saved = {
        ...outfit,
        id: outfit.id || tempId('saved'),
        savedAt: Date.now(),
      };
      setSavedOutfits((prev) => [...prev, saved]);

      if (isSupabaseEnabled && userId) {
        fireCloud(
          db.insertOutfit(saved, userId).then((remote) => {
            setSavedOutfits((prev) =>
              prev.map((o) => (o.id === saved.id ? { ...o, id: remote.id } : o))
            );
          })
        );
      }
      return saved;
    },
    [userId]
  );

  const removeSavedOutfit = useCallback((id) => {
    setSavedOutfits((prev) => prev.filter((o) => o.id !== id));
    if (isSupabaseEnabled) fireCloud(db.deleteOutfit(id));
  }, []);

  // ── Wishlist ──

  const addToWishlist = useCallback(
    (item) => {
      const wishlistItem = {
        ...item,
        id: item.id || tempId('wish'),
        addedAt: Date.now(),
      };
      setWishlist((prev) => [...prev, wishlistItem]);

      if (isSupabaseEnabled && userId) {
        fireCloud(
          db.insertItem(wishlistItem, userId, 'wishlist_items').then((saved) => {
            setWishlist((prev) =>
              prev.map((w) => (w.id === wishlistItem.id ? { ...saved, addedAt: wishlistItem.addedAt } : w))
            );
          })
        );
      }
      return wishlistItem;
    },
    [userId]
  );

  const removeFromWishlist = useCallback((id) => {
    setWishlist((prev) => {
      const target = prev.find((w) => w.id === id);
      if (isSupabaseEnabled && target) {
        fireCloud(db.deleteItemRow(id, target.photoPath, 'wishlist_items'));
      }
      return prev.filter((item) => item.id !== id);
    });
  }, []);

  const moveWishlistToWardrobe = useCallback(
    (wishlistItemId) => {
      setWishlist((prev) => {
        const item = prev.find((w) => w.id === wishlistItemId);
        if (item) {
          const { addedAt, ...wardrobeItem } = item;
          const newItem = {
            ...wardrobeItem,
            id: tempId('item'),
            dateAdded: new Date().toISOString().split('T')[0],
            favorite: false,
          };
          setItems((prevItems) => [...prevItems, newItem]);

          if (isSupabaseEnabled && userId) {
            // La foto su Storage viene riusata dal nuovo capo: si cancella solo la riga
            fireCloud(
              db.insertItem(newItem, userId).then((saved) => {
                setItems((prevItems) =>
                  prevItems.map((i) => (i.id === newItem.id ? saved : i))
                );
                return db.deleteItemRow(wishlistItemId, null, 'wishlist_items');
              })
            );
          }
        }
        return prev.filter((w) => w.id !== wishlistItemId);
      });
    },
    [userId]
  );

  // ── Custom Categories (solo locale, non in scope cloud v1) ──

  const addCustomCategory = useCallback((name, icon) => {
    const category = { id: tempId('custom'), name, icon: icon || '📁' };
    setCustomCategories((prev) => [...prev, category]);
    return category;
  }, []);

  const value = {
    // State
    items,
    outfitHistory,
    wishlist,
    savedOutfits,
    customCategories,
    isSyncing,

    // Item CRUD
    addItem,
    removeItem,
    updateItem,
    toggleFavorite,

    // Outfit history
    logOutfit,
    updateOutfitLog,
    removeOutfitLog,

    // Saved outfits
    saveOutfit,
    removeSavedOutfit,

    // Wishlist
    addToWishlist,
    removeFromWishlist,
    moveWishlistToWardrobe,

    // Custom categories
    addCustomCategory,
  };

  return (
    <WardrobeContext.Provider value={value}>{children}</WardrobeContext.Provider>
  );
}

export function useWardrobe() {
  const context = useContext(WardrobeContext);
  if (!context) {
    throw new Error('useWardrobe must be used within a WardrobeProvider');
  }
  return context;
}

export default WardrobeContext;
