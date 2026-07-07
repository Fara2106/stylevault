import { createContext, useContext, useState, useEffect, useCallback } from 'react';

const WardrobeContext = createContext(null);

// localStorage keys
const KEYS = {
  items: 'sv_items',
  outfitHistory: 'sv_outfit_history',
  wishlist: 'sv_wishlist',
  savedOutfits: 'sv_saved_outfits',
  customCategories: 'sv_custom_categories',
};

/** Sample wardrobe items loaded on first run */
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

/**
 * Load data from localStorage with a fallback default.
 */
function loadFromStorage(key, fallback) {
  try {
    const stored = localStorage.getItem(key);
    if (stored) return JSON.parse(stored);
  } catch (e) {
    console.warn(`Failed to load ${key} from localStorage:`, e);
  }
  return fallback;
}

/**
 * Save data to localStorage.
 */
function saveToStorage(key, data) {
  try {
    localStorage.setItem(key, JSON.stringify(data));
  } catch (e) {
    console.warn(`Failed to save ${key} to localStorage:`, e);
  }
}

/**
 * WardrobeProvider - manages wardrobe items, outfit history, wishlist, and saved outfits.
 */
export function WardrobeProvider({ children }) {
  const [items, setItems] = useState(() => {
    const stored = loadFromStorage(KEYS.items, null);
    // If no stored items, use sample data (first-time load)
    return stored !== null ? stored : SAMPLE_ITEMS;
  });

  const [outfitHistory, setOutfitHistory] = useState(() =>
    loadFromStorage(KEYS.outfitHistory, [])
  );

  const [wishlist, setWishlist] = useState(() =>
    loadFromStorage(KEYS.wishlist, [])
  );

  const [savedOutfits, setSavedOutfits] = useState(() =>
    loadFromStorage(KEYS.savedOutfits, [])
  );

  const [customCategories, setCustomCategories] = useState(() =>
    loadFromStorage(KEYS.customCategories, [])
  );

  // Persist to localStorage whenever state changes
  useEffect(() => { saveToStorage(KEYS.items, items); }, [items]);
  useEffect(() => { saveToStorage(KEYS.outfitHistory, outfitHistory); }, [outfitHistory]);
  useEffect(() => { saveToStorage(KEYS.wishlist, wishlist); }, [wishlist]);
  useEffect(() => { saveToStorage(KEYS.savedOutfits, savedOutfits); }, [savedOutfits]);
  useEffect(() => { saveToStorage(KEYS.customCategories, customCategories); }, [customCategories]);

  // ── Item CRUD ──

  const addItem = useCallback((item) => {
    const newItem = {
      ...item,
      id: item.id || `item_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      dateAdded: item.dateAdded || new Date().toISOString().split('T')[0],
      favorite: item.favorite || false,
    };
    setItems((prev) => [...prev, newItem]);
    return newItem;
  }, []);

  const removeItem = useCallback((id) => {
    setItems((prev) => prev.filter((item) => item.id !== id));
  }, []);

  const updateItem = useCallback((id, updates) => {
    setItems((prev) =>
      prev.map((item) => (item.id === id ? { ...item, ...updates } : item))
    );
  }, []);

  const toggleFavorite = useCallback((id) => {
    setItems((prev) =>
      prev.map((item) =>
        item.id === id ? { ...item, favorite: !item.favorite } : item
      )
    );
  }, []);

  // ── Outfit History ──

  const logOutfit = useCallback((outfit, date) => {
    const log = {
      id: `log_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      outfit,
      date: date || new Date().toISOString().split('T')[0],
      timestamp: Date.now(),
    };
    setOutfitHistory((prev) => [log, ...prev]);
    return log;
  }, []);

  const removeOutfitLog = useCallback((id) => {
    setOutfitHistory((prev) => prev.filter((log) => log.id !== id));
  }, []);

  // ── Saved Outfits ──

  const saveOutfit = useCallback((outfit) => {
    const saved = {
      ...outfit,
      id: outfit.id || `saved_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      savedAt: Date.now(),
    };
    setSavedOutfits((prev) => [...prev, saved]);
    return saved;
  }, []);

  const removeSavedOutfit = useCallback((id) => {
    setSavedOutfits((prev) => prev.filter((o) => o.id !== id));
  }, []);

  // ── Wishlist ──

  const addToWishlist = useCallback((item) => {
    const wishlistItem = {
      ...item,
      id: item.id || `wish_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      addedAt: Date.now(),
    };
    setWishlist((prev) => [...prev, wishlistItem]);
    return wishlistItem;
  }, []);

  const removeFromWishlist = useCallback((id) => {
    setWishlist((prev) => prev.filter((item) => item.id !== id));
  }, []);

  const moveWishlistToWardrobe = useCallback((wishlistItemId) => {
    setWishlist((prev) => {
      const item = prev.find((w) => w.id === wishlistItemId);
      if (item) {
        // Add to wardrobe items (strip wishlist-specific fields)
        const { addedAt, ...wardrobeItem } = item;
        addItem({
          ...wardrobeItem,
          id: undefined, // Let addItem generate a new ID
          dateAdded: new Date().toISOString().split('T')[0],
        });
      }
      return prev.filter((w) => w.id !== wishlistItemId);
    });
  }, [addItem]);

  // ── Custom Categories ──

  const addCustomCategory = useCallback((name, icon) => {
    const category = {
      id: `custom_${Date.now()}_${Math.random().toString(36).substring(2, 5)}`,
      name,
      icon: icon || '📁',
    };
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

    // Item CRUD
    addItem,
    removeItem,
    updateItem,
    toggleFavorite,

    // Outfit history
    logOutfit,
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

/**
 * Hook to access wardrobe context.
 */
export function useWardrobe() {
  const context = useContext(WardrobeContext);
  if (!context) {
    throw new Error('useWardrobe must be used within a WardrobeProvider');
  }
  return context;
}

export default WardrobeContext;
