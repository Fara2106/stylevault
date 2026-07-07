export const CATEGORIES = {
  tops: {
    icon: '👕',
    labelKey: 'categories.tops',
    subcategories: [
      { id: 'tshirt', labelKey: 'subcategories.tshirt' },
      { id: 'shirt', labelKey: 'subcategories.shirt' },
      { id: 'hoodie', labelKey: 'subcategories.hoodie' },
      { id: 'sweater', labelKey: 'subcategories.sweater' },
      { id: 'tank', labelKey: 'subcategories.tank' },
      { id: 'polo', labelKey: 'subcategories.polo' },
      { id: 'croptop', labelKey: 'subcategories.croptop' },
      { id: 'blouse', labelKey: 'subcategories.blouse' },
    ],
  },
  bottoms: {
    icon: '👖',
    labelKey: 'categories.bottoms',
    subcategories: [
      { id: 'jeans', labelKey: 'subcategories.jeans' },
      { id: 'trousers', labelKey: 'subcategories.trousers' },
      { id: 'shorts', labelKey: 'subcategories.shorts' },
      { id: 'skirt', labelKey: 'subcategories.skirt' },
      { id: 'joggers', labelKey: 'subcategories.joggers' },
      { id: 'leggings', labelKey: 'subcategories.leggings' },
      { id: 'dresspants', labelKey: 'subcategories.dressparts' },
    ],
  },
  outerwear: {
    icon: '🧥',
    labelKey: 'categories.outerwear',
    subcategories: [
      { id: 'jacket', labelKey: 'subcategories.jacket' },
      { id: 'coat', labelKey: 'subcategories.coat' },
      { id: 'puffer', labelKey: 'subcategories.puffer' },
      { id: 'blazer', labelKey: 'subcategories.blazer' },
      { id: 'trench', labelKey: 'subcategories.trench' },
      { id: 'vest', labelKey: 'subcategories.vest' },
      { id: 'raincoat', labelKey: 'subcategories.raincoat' },
      { id: 'cardigan', labelKey: 'subcategories.cardigan' },
    ],
  },
  dresses: {
    icon: '👗',
    labelKey: 'categories.dresses',
    subcategories: [
      { id: 'shortdress', labelKey: 'subcategories.shortdress' },
      { id: 'longdress', labelKey: 'subcategories.longdress' },
      { id: 'jumpsuit', labelKey: 'subcategories.jumpsuit' },
      { id: 'eveningdress', labelKey: 'subcategories.eveningdress' },
    ],
  },
  shoes: {
    icon: '👟',
    labelKey: 'categories.shoes',
    subcategories: [
      { id: 'sneakers', labelKey: 'subcategories.sneakers' },
      { id: 'boots', labelKey: 'subcategories.boots' },
      { id: 'loafers', labelKey: 'subcategories.loafers' },
      { id: 'sandals', labelKey: 'subcategories.sandals' },
      { id: 'heels', labelKey: 'subcategories.heels' },
      { id: 'ankleboots', labelKey: 'subcategories.ankleboots' },
      { id: 'pumps', labelKey: 'subcategories.pumps' },
    ],
  },
  accessories: {
    icon: '🧢',
    labelKey: 'categories.accessories',
    subcategories: [
      { id: 'hat', labelKey: 'subcategories.hat' },
      { id: 'scarf', labelKey: 'subcategories.scarf' },
      { id: 'belt', labelKey: 'subcategories.belt' },
      { id: 'bag', labelKey: 'subcategories.bag' },
      { id: 'sunglasses', labelKey: 'subcategories.sunglasses' },
      { id: 'jewelry', labelKey: 'subcategories.jewelry' },
      { id: 'watch', labelKey: 'subcategories.watch' },
      { id: 'umbrella', labelKey: 'subcategories.umbrella' },
    ],
  },
  underwear: {
    icon: '🩲',
    labelKey: 'categories.underwear',
    subcategories: [
      { id: 'underwear_item', labelKey: 'subcategories.underwear_item' },
      { id: 'socks', labelKey: 'subcategories.socks' },
      { id: 'pajamas', labelKey: 'subcategories.pajamas' },
    ],
  },
};

export const SEASONS = [
  { id: 'spring', labelKey: 'seasons.spring', icon: '🌸' },
  { id: 'summer', labelKey: 'seasons.summer', icon: '☀️' },
  { id: 'autumn', labelKey: 'seasons.autumn', icon: '🍂' },
  { id: 'winter', labelKey: 'seasons.winter', icon: '❄️' },
  { id: 'all', labelKey: 'seasons.all', icon: '🔄' },
];

export const OCCASIONS = [
  { id: 'casual', labelKey: 'occasions.casual', icon: '😎' },
  { id: 'formal', labelKey: 'occasions.formal', icon: '👔' },
  { id: 'sport', labelKey: 'occasions.sport', icon: '🏃' },
  { id: 'evening', labelKey: 'occasions.evening', icon: '🌙' },
  { id: 'business', labelKey: 'occasions.business', icon: '💼' },
];

export const CLOTHING_COLORS = [
  { id: 'black', hex: '#1A1A1A', labelKey: 'colors.black' },
  { id: 'white', hex: '#FFFFFF', labelKey: 'colors.white' },
  { id: 'gray', hex: '#9E9E9E', labelKey: 'colors.gray' },
  { id: 'navy', hex: '#1B2A4A', labelKey: 'colors.navy' },
  { id: 'blue', hex: '#4A90D9', labelKey: 'colors.blue' },
  { id: 'lightblue', hex: '#87CEEB', labelKey: 'colors.lightblue' },
  { id: 'red', hex: '#C0392B', labelKey: 'colors.red' },
  { id: 'burgundy', hex: '#722F37', labelKey: 'colors.burgundy' },
  { id: 'pink', hex: '#E8A0B4', labelKey: 'colors.pink' },
  { id: 'green', hex: '#4A7C59', labelKey: 'colors.green' },
  { id: 'olive', hex: '#808000', labelKey: 'colors.olive' },
  { id: 'brown', hex: '#8B4513', labelKey: 'colors.brown' },
  { id: 'tan', hex: '#D2B48C', labelKey: 'colors.tan' },
  { id: 'beige', hex: '#F5F0E1', labelKey: 'colors.beige' },
  { id: 'cream', hex: '#FFFDD0', labelKey: 'colors.cream' },
  { id: 'yellow', hex: '#F4D03F', labelKey: 'colors.yellow' },
  { id: 'orange', hex: '#E67E22', labelKey: 'colors.orange' },
  { id: 'purple', hex: '#7D3C98', labelKey: 'colors.purple' },
  { id: 'lavender', hex: '#B8A9C9', labelKey: 'colors.lavender' },
  { id: 'coral', hex: '#FF7F7F', labelKey: 'colors.coral' },
  { id: 'gold', hex: '#C4A882', labelKey: 'colors.gold' },
  { id: 'silver', hex: '#C0C0C0', labelKey: 'colors.silver' },
  { id: 'denim', hex: '#5B7FA5', labelKey: 'colors.denim' },
  { id: 'khaki', hex: '#BDB76B', labelKey: 'colors.khaki' },
];

export const getCategoryList = () => {
  return Object.entries(CATEGORIES).map(([id, cat]) => ({
    id,
    icon: cat.icon,
    labelKey: cat.labelKey,
  }));
};

export const getSubcategories = (categoryId) => {
  return CATEGORIES[categoryId]?.subcategories || [];
};
