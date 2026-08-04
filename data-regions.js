// Régions et villes principales de Côte d'Ivoire (31 régions + 2 districts autonomes).
// Liste curatée (chef-lieu + principales sous-préfectures/villes de chaque région) :
// un choix "Autre" est ajouté côté interface pour les villes non listées.
const REGIONS_CI = [
  { region: "Abidjan", villes: ["Abidjan", "Abobo", "Adjamé", "Attécoubé", "Cocody", "Koumassi", "Marcory", "Plateau", "Port-Bouët", "Treichville", "Yopougon", "Bingerville", "Anyama", "Songon"] },
  { region: "Yamoussoukro", villes: ["Yamoussoukro", "Attiégouakro", "Lolobo", "Kossou"] },
  { region: "Agnéby-Tiassa", villes: ["Agboville", "Sikensi", "Tiassalé", "Taabo", "Rubino", "Agou"] },
  { region: "Grands Ponts", villes: ["Dabou", "Grand-Lahou", "Jacqueville", "Toupah", "Addah"] },
  { region: "La Mé", villes: ["Adzopé", "Alepé", "Akoupé", "Yakassé-Attobrou", "Afféry"] },
  { region: "Gbôklé", villes: ["Sassandra", "Fresco", "Grand-Zattry"] },
  { region: "Nawa", villes: ["Soubré", "Buyo", "Méagui", "Guéyo"] },
  { region: "San-Pédro", villes: ["San-Pédro", "Tabou", "Grand-Béréby"] },
  { region: "Indénié-Djuablin", villes: ["Abengourou", "Agnibilékrou", "Bettié", "Niablé", "Zaranou"] },
  { region: "Sud-Comoé", villes: ["Aboisso", "Grand-Bassam", "Adiaké", "Tiapoum", "Ayamé", "Bonoua"] },
  { region: "Folon", villes: ["Minignan", "Kaniasso"] },
  { region: "Kabadougou", villes: ["Odienné", "Madinani", "Samatiguila"] },
  { region: "Gôh", villes: ["Gagnoa", "Oumé", "Ouragahio"] },
  { region: "Lôh-Djiboua", villes: ["Divo", "Lakota", "Guitry", "Hiré"] },
  { region: "Bélier", villes: ["Toumodi", "Didiévi", "Tiébissou", "Djékanou"] },
  { region: "Iffou", villes: ["Daoukro", "Prikro", "M'Bahiakro"] },
  { region: "Moronou", villes: ["Bongouanou", "Arrah", "M'Batto", "Anoumaba"] },
  { region: "N'Zi", villes: ["Dimbokro", "Bocanda", "Kouassi-Kouassikro"] },
  { region: "Cavally", villes: ["Guiglo", "Bloléquin", "Taï", "Toulepleu"] },
  { region: "Guémon", villes: ["Duékoué", "Bangolo", "Facobly", "Kouibly"] },
  { region: "Tonkpi", villes: ["Man", "Biankouma", "Danané", "Zouan-Hounien", "Sipilou"] },
  { region: "Haut-Sassandra", villes: ["Daloa", "Vavoua", "Issia", "Zoukougbeu"] },
  { region: "Marahoué", villes: ["Bouaflé", "Sinfra", "Zuénoula", "Bonon"] },
  { region: "Gbêkê", villes: ["Bouaké", "Béoumi", "Sakassou", "Botro"] },
  { region: "Hambol", villes: ["Katiola", "Dabakala", "Niakaramandougou"] },
  { region: "Bafing", villes: ["Touba", "Koro", "Ouaninou"] },
  { region: "Bérè", villes: ["Mankono", "Kounahiri", "Dianra"] },
  { region: "Worodougou", villes: ["Séguéla", "Kani", "Massala"] },
  { region: "Bounkani", villes: ["Bouna", "Doropo", "Nassian", "Téhini"] },
  { region: "Gontougo", villes: ["Bondoukou", "Tanda", "Koun-Fao", "Sandégué", "Transua"] },
  { region: "Bagoué", villes: ["Boundiali", "Tengréla", "Kouto", "Kolia"] },
  { region: "Poro", villes: ["Korhogo", "Sinématiali", "M'Bengué", "Dikodougou"] },
  { region: "Tchologo", villes: ["Ferkessédougou", "Ouangolodougou", "Kong"] },
];

function espRegionsListe(){
  return REGIONS_CI.map(r => r.region);
}
function espVillesPourRegion(region){
  const r = REGIONS_CI.find(x => x.region === region);
  return r ? r.villes : [];
}
