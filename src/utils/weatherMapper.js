/**
 * Weather mapper utilities for StyleVault.
 * Provides mock weather data, warmth calculations, and weather-based recommendations.
 */

const CITY_WEATHER = {
  milano: {
    temperature: 32,
    feelsLike: 35,
    humidity: 55,
    windSpeed: 8,
    uvIndex: 8,
    rain: false,
    snow: false,
    description: 'Soleggiato e caldo',
    icon: '☀️',
    city: 'Milano',
  },
  roma: {
    temperature: 35,
    feelsLike: 38,
    humidity: 45,
    windSpeed: 10,
    uvIndex: 9,
    rain: false,
    snow: false,
    description: 'Soleggiato e molto caldo',
    icon: '🔥',
    city: 'Roma',
  },
  london: {
    temperature: 14,
    feelsLike: 11,
    humidity: 82,
    windSpeed: 22,
    uvIndex: 2,
    rain: true,
    snow: false,
    description: 'Pioggia leggera',
    icon: '🌧️',
    city: 'London',
  },
  paris: {
    temperature: 18,
    feelsLike: 16,
    humidity: 65,
    windSpeed: 15,
    uvIndex: 4,
    rain: false,
    snow: false,
    description: 'Nuvoloso',
    icon: '☁️',
    city: 'Paris',
  },
  'new york': {
    temperature: 28,
    feelsLike: 33,
    humidity: 78,
    windSpeed: 12,
    uvIndex: 7,
    rain: false,
    snow: false,
    description: 'Caldo e umido',
    icon: '🌤️',
    city: 'New York',
  },
  tokyo: {
    temperature: 30,
    feelsLike: 36,
    humidity: 85,
    windSpeed: 6,
    uvIndex: 6,
    rain: false,
    snow: false,
    description: 'Molto umido',
    icon: '🌫️',
    city: 'Tokyo',
  },
  reykjavik: {
    temperature: 5,
    feelsLike: -1,
    humidity: 70,
    windSpeed: 35,
    uvIndex: 1,
    rain: false,
    snow: false,
    description: 'Freddo e ventoso',
    icon: '💨',
    city: 'Reykjavik',
  },
  berlin: {
    temperature: 20,
    feelsLike: 19,
    humidity: 58,
    windSpeed: 14,
    uvIndex: 5,
    rain: false,
    snow: false,
    description: 'Mite e piacevole',
    icon: '🌤️',
    city: 'Berlin',
  },
  firenze: {
    temperature: 33,
    feelsLike: 35,
    humidity: 50,
    windSpeed: 7,
    uvIndex: 9,
    rain: false,
    snow: false,
    description: 'Soleggiato',
    icon: '☀️',
    city: 'Firenze',
  },
  napoli: {
    temperature: 34,
    feelsLike: 37,
    humidity: 60,
    windSpeed: 12,
    uvIndex: 9,
    rain: false,
    snow: false,
    description: 'Soleggiato e afoso',
    icon: '☀️',
    city: 'Napoli',
  },
  amsterdam: {
    temperature: 16,
    feelsLike: 13,
    humidity: 75,
    windSpeed: 20,
    uvIndex: 3,
    rain: true,
    snow: false,
    description: 'Pioggia intermittente',
    icon: '🌦️',
    city: 'Amsterdam',
  },
  oslo: {
    temperature: 8,
    feelsLike: 4,
    humidity: 68,
    windSpeed: 18,
    uvIndex: 2,
    rain: false,
    snow: false,
    description: 'Freddo e nuvoloso',
    icon: '🌥️',
    city: 'Oslo',
  },
};

/**
 * Get mock weather data for a given city.
 * Falls back to Milano if city not found.
 * @param {string} city - City name
 * @returns {object} Weather conditions object
 */
export function getMockWeather(city) {
  const key = city?.toLowerCase().trim() || 'milano';
  return CITY_WEATHER[key] || {
    ...CITY_WEATHER.milano,
    city: city || 'Milano',
  };
}

/**
 * Calculate warmth target based on temperature and wind speed.
 * Uses wind chill approximation for temperatures below 10°C.
 * @param {number} temperature - Temperature in Celsius
 * @param {number} windSpeed - Wind speed in km/h
 * @returns {number} Warmth level 1-5 (1=very light, 5=very heavy)
 */
export function getWarmthTarget(temperature, windSpeed = 0) {
  // Wind chill approximation (simplified)
  let effectiveTemp = temperature;
  if (temperature <= 10 && windSpeed > 4.8) {
    effectiveTemp =
      13.12 +
      0.6215 * temperature -
      11.37 * Math.pow(windSpeed, 0.16) +
      0.3965 * temperature * Math.pow(windSpeed, 0.16);
  } else if (temperature < 20) {
    // Mild wind cooling effect
    effectiveTemp = temperature - windSpeed * 0.1;
  }

  if (effectiveTemp >= 30) return 1; // Very light clothing
  if (effectiveTemp >= 22) return 2; // Light clothing
  if (effectiveTemp >= 15) return 3; // Medium layers
  if (effectiveTemp >= 5) return 4;  // Warm layers
  return 5;                          // Heavy winter gear
}

/**
 * Get clothing recommendations based on weather conditions.
 * @param {object} conditions - Weather conditions from getMockWeather
 * @returns {string[]} Array of recommendation strings
 */
export function getWeatherRecommendations(conditions) {
  const recommendations = [];

  // Temperature-based
  if (conditions.temperature >= 30) {
    recommendations.push('Indossa tessuti leggeri e traspiranti');
    recommendations.push('Scegli colori chiari per riflettere il sole');
  } else if (conditions.temperature >= 22) {
    recommendations.push('Perfetto per capi leggeri');
  } else if (conditions.temperature >= 15) {
    recommendations.push('Porta una giacca leggera o un cardigan');
  } else if (conditions.temperature >= 5) {
    recommendations.push('Vestiti a strati per il freddo');
    recommendations.push('Un cappotto caldo è consigliato');
  } else {
    recommendations.push('Necessario abbigliamento invernale pesante');
    recommendations.push('Non dimenticare sciarpa e guanti');
  }

  // Rain
  if (conditions.rain) {
    recommendations.push('Porta un ombrello o un impermeabile');
    recommendations.push('Scegli scarpe impermeabili');
  }

  // Snow
  if (conditions.snow) {
    recommendations.push('Stivali impermeabili consigliati');
    recommendations.push('Vestiti con strati termici');
  }

  // Wind
  if (conditions.windSpeed > 25) {
    recommendations.push('Vento forte: evita capi leggeri e svolazzanti');
  } else if (conditions.windSpeed > 15) {
    recommendations.push('Porta una giacca antivento');
  }

  // UV
  if (conditions.uvIndex >= 6) {
    recommendations.push('Indice UV alto: porta occhiali da sole e cappello');
  }

  // Humidity
  if (conditions.humidity > 75 && conditions.temperature > 25) {
    recommendations.push('Umidità alta: preferisci tessuti in cotone o lino');
  }

  return recommendations;
}

/**
 * Get a CSS color representing the temperature range.
 * @param {number} temp - Temperature in Celsius
 * @returns {string} CSS color string
 */
export function getTemperatureColor(temp) {
  if (temp <= 0) return '#A8D8EA';       // Icy blue pastel
  if (temp <= 10) return '#B8D4E3';      // Cool blue pastel
  if (temp <= 18) return '#B5E8C3';      // Green pastel (mild)
  if (temp <= 25) return '#C8E6B0';      // Warm green pastel
  if (temp <= 30) return '#F5D89A';      // Warm orange pastel
  if (temp <= 35) return '#F2C6C2';      // Warm pink pastel
  return '#E8A0A0';                      // Hot pink/red pastel
}
