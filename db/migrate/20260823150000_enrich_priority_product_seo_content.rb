class EnrichPriorityProductSeoContent < ActiveRecord::Migration[8.1]
  CONTENT = {
    "yara-lattafa" => {
      short_description: "Yara de Lattafa associe mandarine, orchidée et notes tropicales à un fond gourmand de vanille, musc et bois de santal.",
      description: "Yara de Lattafa est une eau de parfum féminine aux facettes gourmandes et florales. La mandarine, l’héliotrope et l’orchidée ouvrent la composition avant des notes tropicales et un accord gourmand, sur un fond de vanille, musc et bois de santal.",
      meta_title: "Yara Lattafa | Parfum gourmand floral 10, 50 & 100 ml | ADURA",
      meta_description: "Yara de Lattafa : un parfum féminin gourmand et floral, entre orchidée, notes tropicales, vanille, musc et bois de santal."
    },
    "khamrah" => {
      short_description: "Khamrah de Lattafa réunit bergamote, cannelle, datte et praliné sur un fond ambré, vanillé et boisé.",
      description: "Khamrah de Lattafa est une eau de parfum unisexe aux accents gourmands et épicés. La bergamote, la cannelle et la noix de muscade précèdent un cœur de datte, praliné et tubéreuse, prolongé par la vanille, l’ambre, la fève tonka et les bois.",
      meta_title: "Khamrah Lattafa 100 ml | Parfum gourmand épicé | ADURA",
      meta_description: "Découvrez Khamrah de Lattafa, un parfum unisexe gourmand et épicé aux notes de datte, praliné, cannelle, vanille et ambre."
    },
    "nebras" => {
      short_description: "Nebras de Lattafa Pride marie fruits rouges, cacao et vanille, avec un fond de tonka, ambre, musc et sucre.",
      description: "Nebras de Lattafa Pride est une eau de parfum unisexe gourmande. Les fruits rouges et la mandarine introduisent un cœur de vanille, cacao et rose ; la fève tonka, l’ambre, le musc et le sucre apportent la signature finale de la composition.",
      meta_title: "Nebras Lattafa Pride 100 ml | Vanille, cacao & fruits rouges | ADURA",
      meta_description: "Nebras de Lattafa Pride : un parfum gourmand unisexe mêlant fruits rouges, cacao, vanille, fève tonka, ambre et musc."
    },
    "ameerat-al-arab-prive-rose" => {
      short_description: "Ameerat Al Arab Privé Rose d’Asdaaf mêle fruits, rose et fleurs blanches à un fond ambré, tonka et bois de santal.",
      description: "Ameerat Al Arab Privé Rose d’Asdaaf est une eau de parfum féminine florale et fruitée. Fraise, raisin et orange ouvrent la composition, suivis de rose, gardénia, jasmin et ylang-ylang, avant un fond de fève tonka, ambre et bois de santal.",
      meta_title: "Ameerat Al Arab Privé Rose Asdaaf 100 ml | ADURA",
      meta_description: "Ameerat Al Arab Privé Rose d’Asdaaf : un parfum féminin floral et fruité aux notes de rose, fleurs blanches, ambre et santal."
    },
    "kenzie-amber-lychee" => {
      short_description: "Kenzie Amber Lychee de Volaré associe litchi, pomme et cassis à la rose, la vanille, l’ambre et des bois doux.",
      description: "Kenzie Amber Lychee de Volaré est une eau de parfum unisexe fruitée et fraîche. Litchi, cassis, pomme rouge et citron italien rencontrent la rose de Damas et le jasmin sambac, puis un fond d’ambre, vanille, musc et bois.",
      meta_title: "Kenzie Amber Lychee Volaré 100 ml | Parfum fruité | ADURA",
      meta_description: "Kenzie Amber Lychee de Volaré : un parfum fruité et frais autour du litchi, du cassis, de la rose, de la vanille et de l’ambre."
    },
    "kenzie-candid-vanilla" => {
      short_description: "Kenzie Candid Vanilla de Volaré dévoile plusieurs facettes de vanille, relevées d’agrumes, fleur d’oranger, ambre et musc.",
      description: "Kenzie Candid Vanilla de Volaré est une eau de parfum unisexe gourmande. La vanille et les agrumes ouvrent la composition, avant une vanille crémeuse et la fleur d’oranger ; le bois de santal, le musc et l’ambre accompagnent le fond.",
      meta_title: "Kenzie Candid Vanilla Volaré 100 ml | Parfum gourmand | ADURA",
      meta_description: "Kenzie Candid Vanilla de Volaré : un parfum gourmand unisexe aux notes de vanille, agrumes, fleur d’oranger, santal, musc et ambre."
    },
    "kenzie-classic-pistachio" => {
      short_description: "Kenzie Classic Pistachio de Volaré associe pistache, amande et bergamote à une crème de pistache, vanille, tonka et musc blanc.",
      description: "Kenzie Classic Pistachio de Volaré est une eau de parfum unisexe gourmande. Pistache, amande et bergamote précèdent un cœur de crème de pistache, jasmin et vanille, avant un fond de bois de santal, fève tonka, musc blanc et ambre.",
      meta_title: "Kenzie Classic Pistachio Volaré 100 ml | Parfum gourmand | ADURA",
      meta_description: "Kenzie Classic Pistachio de Volaré : un parfum gourmand unisexe avec pistache, amande, vanille, fève tonka, musc blanc et ambre."
    },
    "kenzie-marshmallow-dream" => {
      short_description: "Kenzie Marshmallow Dream de Volaré compose un accord gourmand autour de la guimauve, de la vanille, de la fleur d’oranger et du musc blanc.",
      description: "Kenzie Marshmallow Dream de Volaré est une eau de parfum unisexe gourmande. La guimauve et la vanille donnent le ton, accompagnées par la fleur d’oranger et un sucre doux, puis par un fond de musc blanc.",
      meta_title: "Kenzie Marshmallow Dream Volaré 100 ml | ADURA",
      meta_description: "Kenzie Marshmallow Dream de Volaré : un parfum gourmand unisexe aux notes de guimauve, vanille, fleur d’oranger, sucre doux et musc blanc."
    },
    "her-confession" => {
      short_description: "Her Confession de Lattafa associe cannelle, jasmin et tubéreuse à la vanille, la fève tonka, le musc et l’encens.",
      description: "Her Confession de Lattafa est une eau de parfum féminine florale. Un accord mystique et la cannelle précèdent le jasmin, la tubéreuse, l’encens et le mahonial, avant un fond de fève tonka, musc et vanille.",
      meta_title: "Her Confession Lattafa 100 ml | Parfum floral | ADURA",
      meta_description: "Her Confession de Lattafa : un parfum féminin floral aux notes de cannelle, jasmin, tubéreuse, encens, vanille, tonka et musc."
    },
    "angham-second-song" => {
      short_description: "Angham Second Song de Lattafa mêle bergamote, poire et fleurs à un cœur praliné, puis vanille, tonka, ambroxan et musc.",
      description: "Angham Second Song de Lattafa est une eau de parfum féminine florale et gourmande. Bergamote, poire et fleur de poirier ouvrent la composition ; fleur d’oranger, pivoine et praliné s’accordent ensuite à la vanille, la fève tonka, l’ambroxan et le musc.",
      meta_title: "Angham Second Song Lattafa 100 ml | Floral gourmand | ADURA",
      meta_description: "Angham Second Song de Lattafa : un parfum féminin floral et gourmand aux notes de poire, fleur d’oranger, pivoine, praliné et vanille."
    }
  }.freeze

  def up
    product_class = Class.new(ActiveRecord::Base) do
      self.table_name = "products"
    end

    # La base CI est volontairement créée vide, sans catalogue seedé. Une
    # migration éditoriale ne doit donc pas empêcher la validation de toutes
    # les migrations dans cet environnement. Toute base contenant un
    # catalogue reste, elle, vérifiée strictement ci-dessous.
    return if product_class.none?

    CONTENT.each do |slug, attributes|
      products = product_class.where(slug: slug)
      raise "Produit prioritaire introuvable ou dupliqué : #{slug}" unless products.count == 1

      products.update_all(attributes.merge(updated_at: Time.current))
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Les contenus éditoriaux précédents ne sont pas restaurés automatiquement."
  end
end
