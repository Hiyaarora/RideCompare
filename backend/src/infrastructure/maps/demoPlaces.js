/**
 * Well-known public landmarks used for location search when no Google Maps key is configured.
 * Coordinates are approximate and only used to generate demo estimates.
 */
const raw = [
  // Bengaluru
  ['blr-mg-road', 'MG Road Metro Station', 'Mahatma Gandhi Rd, Bengaluru, Karnataka', 12.9755, 77.6068],
  ['blr-koramangala', 'Koramangala 5th Block', 'Koramangala, Bengaluru, Karnataka', 12.9352, 77.6245],
  ['blr-indiranagar', 'Indiranagar 100 Feet Road', 'HAL 2nd Stage, Indiranagar, Bengaluru, Karnataka', 12.9719, 77.6412],
  ['blr-whitefield', 'Whitefield ITPL', 'Whitefield Main Rd, Bengaluru, Karnataka', 12.9857, 77.7310],
  ['blr-electronic-city', 'Electronic City Phase 1', 'Hosur Rd, Electronic City, Bengaluru, Karnataka', 12.8452, 77.6602],
  ['blr-airport', 'Kempegowda International Airport', 'Devanahalli, Bengaluru, Karnataka', 13.1986, 77.7066],
  ['blr-majestic', 'Majestic (KSR Bengaluru City Junction)', 'Gubbi Thotadappa Rd, Bengaluru, Karnataka', 12.9781, 77.5695],
  ['blr-hsr', 'HSR Layout Sector 1', 'HSR Layout, Bengaluru, Karnataka', 12.9121, 77.6446],
  ['blr-jayanagar', 'Jayanagar 4th Block', 'Jayanagar, Bengaluru, Karnataka', 12.9293, 77.5826],
  ['blr-manyata', 'Manyata Tech Park', 'Nagavara, Bengaluru, Karnataka', 13.0475, 77.6206],
  ['blr-lalbagh', 'Lalbagh Botanical Garden', 'Mavalli, Bengaluru, Karnataka', 12.9507, 77.5848],
  // Delhi NCR
  ['del-cp', 'Connaught Place', 'Connaught Place, New Delhi, Delhi', 28.6315, 77.2167],
  ['del-indiagate', 'India Gate', 'Kartavya Path, New Delhi, Delhi', 28.6129, 77.2295],
  ['del-airport-t3', 'IGI Airport Terminal 3', 'Indira Gandhi International Airport, New Delhi, Delhi', 28.5562, 77.1000],
  ['del-ndls', 'New Delhi Railway Station', 'Paharganj, New Delhi, Delhi', 28.6430, 77.2194],
  ['del-hauzkhas', 'Hauz Khas Village', 'Hauz Khas, New Delhi, Delhi', 28.5535, 77.1940],
  ['del-saket', 'Select Citywalk, Saket', 'Saket District Centre, New Delhi, Delhi', 28.5286, 77.2190],
  ['ggn-cyber-city', 'DLF Cyber City', 'DLF Phase 2, Gurugram, Haryana', 28.4950, 77.0895],
  ['noida-sec18', 'Noida Sector 18', 'Sector 18, Noida, Uttar Pradesh', 28.5708, 77.3261],
  // Mumbai
  ['bom-gateway', 'Gateway of India', 'Apollo Bandar, Colaba, Mumbai, Maharashtra', 18.9220, 72.8347],
  ['bom-bkc', 'Bandra Kurla Complex', 'Bandra East, Mumbai, Maharashtra', 19.0660, 72.8686],
  ['bom-airport-t2', 'Mumbai Airport Terminal 2', 'Andheri East, Mumbai, Maharashtra', 19.0989, 72.8746],
  ['bom-andheri', 'Andheri Station (West)', 'Andheri West, Mumbai, Maharashtra', 19.1197, 72.8464],
  ['bom-powai', 'Hiranandani Gardens, Powai', 'Powai, Mumbai, Maharashtra', 19.1176, 72.9060],
  ['bom-csmt', 'Chhatrapati Shivaji Maharaj Terminus', 'Fort, Mumbai, Maharashtra', 18.9398, 72.8355],
  ['bom-juhu', 'Juhu Beach', 'Juhu, Mumbai, Maharashtra', 19.0988, 72.8267],
  // Hyderabad
  ['hyd-hitech', 'HITEC City', 'Madhapur, Hyderabad, Telangana', 17.4435, 78.3772],
  ['hyd-charminar', 'Charminar', 'Char Kaman, Ghansi Bazaar, Hyderabad, Telangana', 17.3616, 78.4747],
  ['hyd-airport', 'Rajiv Gandhi International Airport', 'Shamshabad, Hyderabad, Telangana', 17.2403, 78.4294],
  ['hyd-gachibowli', 'Gachibowli Stadium', 'Gachibowli, Hyderabad, Telangana', 17.4483, 78.3489],
  ['hyd-banjara', 'Banjara Hills Road No. 1', 'Banjara Hills, Hyderabad, Telangana', 17.4126, 78.4482],
  // Chennai
  ['maa-tnagar', 'T. Nagar Pondy Bazaar', 'Thyagaraya Nagar, Chennai, Tamil Nadu', 13.0418, 80.2341],
  ['maa-marina', 'Marina Beach', 'Triplicane, Chennai, Tamil Nadu', 13.0500, 80.2824],
  ['maa-central', 'Chennai Central Railway Station', 'Park Town, Chennai, Tamil Nadu', 13.0827, 80.2757],
  ['maa-airport', 'Chennai International Airport', 'Meenambakkam, Chennai, Tamil Nadu', 12.9941, 80.1709],
  // Pune
  ['pnq-fc-road', 'FC Road', 'Shivajinagar, Pune, Maharashtra', 18.5236, 73.8412],
  ['pnq-hinjewadi', 'Hinjewadi Phase 1', 'Hinjewadi, Pune, Maharashtra', 18.5913, 73.7389],
  ['pnq-koregaon', 'Koregaon Park', 'Koregaon Park, Pune, Maharashtra', 18.5362, 73.8940],
  ['pnq-airport', 'Pune Airport', 'Lohegaon, Pune, Maharashtra', 18.5821, 73.9197],
];

export const DEMO_PLACES = Object.freeze(
  raw.map(([id, name, address, lat, lng]) => Object.freeze({ placeId: `demo:${id}`, name, address, lat, lng })),
);
