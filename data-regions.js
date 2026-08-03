// Régions et villes principales de Côte d'Ivoire (31 régions + 2 districts autonomes).
// Liste curatée (villes principales par région) : un choix "Autre" est ajouté côté
// interface pour les villes non listées.
const REGIONS_CI = [
  { region: "Abidjan", villes: ["Abidjan"] },
  { region: "Yamoussoukro", villes: ["Yamoussoukro", "Attiégouakro"] },
  { region: "Agnéby-Tiassa", villes: ["Agboville", "Sikensi", "Tiassalé", "Taabo"] },
  { region: "Grands Ponts", villes: ["Dabou", "Grand-Lahou", "Jacqueville"] },
  { region: "La Mé", villes: ["Adzopé", "Alepé", "Akoupé"] },
  { region: "Gbôklé", villes: ["Sassandra", "Fresco"] },
  { region: "Nawa", villes: ["Soubré", "Buyo", "Méagui"] },
  { region: "San-Pédro", villes: ["San-Pédro", "Tabou"] },
  { region: "Indénié-Djuablin", villes: ["Abengourou", "Agnibilékrou", "Bettié"] },
  { region: "Sud-Comoé", villes: ["Aboisso", "Grand-Bassam", "Adiaké", "Tiapoum"] },
  { region: "Folon", villes: ["Minignan"] },
  { region: "Kabadougou", villes: ["Odienné"] },
  { region: "Gôh", villes: ["Gagnoa", "Oumé"] },
  { region: "Lôh-Djiboua", villes: ["Divo", "Lakota", "Guitry"] },
  { region: "Bélier", villes: ["Toumodi", "Didiévi", "Tiébissou"] },
  { region: "Iffou", villes: ["Daoukro", "Prikro"] },
  { region: "Moronou", villes: ["Bongouanou", "Arrah", "M'Batto"] },
  { region: "N'Zi", villes: ["Dimbokro", "Bocanda"] },
  { region: "Cavally", villes: ["Guiglo", "Bloléquin", "Taï"] },
  { region: "Guémon", villes: ["Duékoué", "Bangolo"] },
  { region: "Tonkpi", villes: ["Man", "Biankouma", "Danané", "Zouan-Hounien"] },
  { region: "Haut-Sassandra", villes: ["Daloa", "Vavoua", "Issia", "Zoukougbeu"] },
  { region: "Marahoué", villes: ["Bouaflé", "Sinfra", "Zuénoula"] },
  { region: "Gbêkê", villes: ["Bouaké", "Béoumi", "Sakassou"] },
  { region: "Hambol", villes: ["Katiola", "Dabakala", "Niakaramandougou"] },
  { region: "Bafing", villes: ["Touba", "Koro"] },
  { region: "Bérè", villes: ["Mankono", "Kounahiri"] },
  { region: "Worodougou", villes: ["Séguéla", "Kani"] },
  { region: "Bounkani", villes: ["Bouna", "Doropo"] },
  { region: "Gontougo", villes: ["Bondoukou", "Tanda", "Koun-Fao"] },
  { region: "Bagoué", villes: ["Boundiali", "Tengréla", "Kouto"] },
  { region: "Poro", villes: ["Korhogo", "Sinématiali", "M'Bengué"] },
  { region: "Tchologo", villes: ["Ferkessédougou", "Ouangolodougou"] },
];

function espRegionsListe(){
  return REGIONS_CI.map(r => r.region);
}
function espVillesPourRegion(region){
  const r = REGIONS_CI.find(x => x.region === region);
  return r ? r.villes : [];
}
