class EnrichRemainingProductSeoContent < ActiveRecord::Migration[8.1]
  CONTENT = {
    "ameerat-al-arab-rouge" => {
      short_description: "Ameerat Al Arab Rouge d’Asdaaf associe miel, orange et jasmin à un fond doux de vanille, orris et bois de santal.",
      description: "Ameerat Al Arab Rouge d’Asdaaf est une eau de parfum féminine florale aux accents doux et lumineux. Le miel, l’orange et les notes vertes ouvrent la composition avant le jasmin. La vanille, l’orris et le bois de santal installent ensuite un fond plus enveloppant, qui prolonge son caractère floral.",
      meta_title: "Ameerat Al Arab Rouge Asdaaf 100 ml | Parfum floral | ADURA",
      meta_description: "Ameerat Al Arab Rouge d’Asdaaf : un parfum femme floral aux notes de miel, orange, jasmin, vanille, orris et bois de santal."
    },
    "ameerat-al-arab-sugar-crown" => {
      short_description: "Ameerat Al Arab Sugar Crown d’Asdaaf mêle agrumes, fruits confits et rose à un fond musqué, ambré et boisé.",
      description: "Ameerat Al Arab Sugar Crown d’Asdaaf est une eau de parfum féminine fruitée et florale. L’orange amère, le citron et les fruits confits donnent une ouverture vive, suivie d’un accord chewing-gum, de rose de Bulgarie, de pêche et de myrtille. L’ambroxan, le musc et le cèdre apportent une finition plus douce et boisée.",
      meta_title: "Ameerat Al Arab Sugar Crown Asdaaf 100 ml | ADURA",
      meta_description: "Ameerat Al Arab Sugar Crown d’Asdaaf : un parfum femme fruité avec agrumes, fruits confits, rose, pêche, musc et cèdre."
    },
    "ana-abiyedh" => {
      short_description: "Ana Abiyedh de Lattafa associe orange et bergamote à la poire, la vanille, le musc et un accord d’ambre sec.",
      description: "Ana Abiyedh, aussi appelé I Am White, de Lattafa est une eau de parfum unisexe musquée. L’orange et la bergamote ouvrent la composition avec une facette fraîche, avant la poire et la vanille. Le musc et l’ambre sec structurent le fond et donnent à l’ensemble une signature douce, propre et légèrement ambrée.",
      meta_title: "Ana Abiyedh Lattafa 60 ml | Parfum musqué | ADURA",
      meta_description: "Ana Abiyedh de Lattafa : un parfum unisexe musqué aux notes d’orange, bergamote, poire, vanille, musc et ambre sec."
    },
    "asad" => {
      short_description: "Asad de Lattafa combine poivre noir, ananas et tabac avec café, iris, ambre, vanille et bois secs.",
      description: "Asad de Lattafa est une eau de parfum masculine boisée aux facettes épicées et ambrées. Le poivre noir, l’ananas et le tabac ouvrent le parfum, puis le café, l’iris et le patchouli prennent place au cœur. L’ambre, la vanille, les bois secs, le benjoin et le labdanum composent un fond chaud et profond.",
      meta_title: "Asad Lattafa 100 ml | Parfum homme boisé ambré | ADURA",
      meta_description: "Asad de Lattafa : un parfum homme boisé et ambré aux notes de poivre noir, tabac, café, iris, vanille et benjoin."
    },
    "asad-zanzibar" => {
      short_description: "Asad Zanzibar de Lattafa mêle poivre noir et lavande de mer à l’eau de coco salée, l’iris, la vanille et l’encens.",
      description: "Asad Zanzibar de Lattafa est une eau de parfum masculine boisée, entre fraîcheur aromatique et douceur saline. Le poivre noir et la lavande de mer introduisent la composition. L’eau de coco salée et l’iris apportent une facette originale au cœur, tandis que la vanille et l’encens prolongent le parfum sur un fond plus chaud.",
      meta_title: "Asad Zanzibar Lattafa 100 ml | Parfum homme boisé | ADURA",
      meta_description: "Asad Zanzibar de Lattafa : un parfum homme boisé aux notes de poivre noir, eau de coco salée, iris, vanille et encens."
    },
    "bab-al-wardi" => {
      short_description: "Bab Al Wardi d’Ard Al Zaafaran associe litchi, poire et bergamote à la rose, au jasmin, au musc et à l’ambre.",
      description: "Bab Al Wardi d’Ard Al Zaafaran est une eau de parfum féminine florale et fruitée. Le litchi, la poire et la bergamote donnent une ouverture lumineuse. La rose, le jasmin et le muguet composent le cœur, avant un fond de patchouli, musc et ambre qui apporte une profondeur plus douce à la composition.",
      meta_title: "Bab Al Wardi Ard Al Zaafaran 100 ml | Parfum floral | ADURA",
      meta_description: "Bab Al Wardi d’Ard Al Zaafaran : un parfum femme floral et fruité aux notes de litchi, poire, rose, jasmin, musc et ambre."
    },
    "badee-al-oud-amethyst" => {
      short_description: "Badee Al Oud Amethyst de Lattafa mêle poivre rose et bergamote à la rose, au jasmin, à l’oud, l’ambre et la vanille.",
      description: "Badee Al Oud Amethyst de Lattafa est une eau de parfum unisexe boisée et florale. Le poivre rose et la bergamote ouvrent la composition avec éclat. Deux expressions de rose, turque et bulgare, rencontrent le jasmin au cœur. Le bois d’oud, l’ambre et la vanille constituent ensuite un fond chaud et enveloppant.",
      meta_title: "Badee Al Oud Amethyst Lattafa 100 ml | Oud floral | ADURA",
      meta_description: "Badee Al Oud Amethyst de Lattafa : un parfum unisexe aux notes de rose, jasmin, oud, ambre, vanille, poivre rose et bergamote."
    },
    "kenzie-exotic-apple-crush" => {
      short_description: "Kenzie Exotic Apple Crush de Volaré associe pomme verte, jasmin et freesia à un fond de vanille et musc doux.",
      description: "Kenzie Exotic Apple Crush de Volaré est une eau de parfum féminine fruitée et florale. La pomme verte ouvre le parfum avec une facette fraîche et croquante. Le jasmin et le freesia prennent ensuite place au cœur, avant un fond de musc doux et de vanille qui donne une finition plus ronde et délicate.",
      meta_title: "Kenzie Exotic Apple Crush Volaré 100 ml | ADURA",
      meta_description: "Kenzie Exotic Apple Crush de Volaré : un parfum femme fruité aux notes de pomme verte, jasmin, freesia, vanille et musc doux."
    },
    "kenzie-irish-vanilla" => {
      short_description: "Kenzie Irish Vanilla de Volaré associe vanille verte, lait d’amande et bergamote à une crème de vanille, tonka et musc blanc.",
      description: "Kenzie Irish Vanilla de Volaré est une eau de parfum unisexe gourmande centrée sur des facettes de vanille. La vanille verte, le lait d’amande et la bergamote introduisent la composition. La crème de vanille, le bois de cachemire et la fève tonka donnent du relief au cœur, avant le musc blanc, le santal et l’ambre doré.",
      meta_title: "Kenzie Irish Vanilla Volaré 100 ml | Parfum vanillé | ADURA",
      meta_description: "Kenzie Irish Vanilla de Volaré : un parfum unisexe vanillé avec lait d’amande, bergamote, tonka, musc blanc, santal et ambre."
    },
    "kenzie-summer-bottled" => {
      short_description: "Kenzie Summer Bottled de Volaré mêle citron et bergamote à des notes aquatiques, une fleur blanche, du musc et des bois clairs.",
      description: "Kenzie Summer Bottled de Volaré est une eau de parfum féminine florale aux accents frais. Le citron, la bergamote et les notes fraîches ouvrent la composition. Les notes aquatiques et la fleur blanche occupent le cœur, puis le musc blanc, les bois clairs et un accord doux donnent une finition souple et lumineuse.",
      meta_title: "Kenzie Summer Bottled Volaré 100 ml | Parfum frais | ADURA",
      meta_description: "Kenzie Summer Bottled de Volaré : un parfum femme frais aux notes de citron, bergamote, accord aquatique, fleur blanche, musc et bois clairs."
    },
    "kenzie-vanilla-70" => {
      short_description: "Kenzie Vanilla 70 de Volaré associe bergamote et fleur d’oranger à la vanille de Madagascar, au jasmin, au santal et au musc blanc.",
      description: "Kenzie Vanilla 70 de Volaré est une eau de parfum unisexe gourmande autour de la vanille. La bergamote et la fleur d’oranger apportent une ouverture claire. La vanille de Madagascar et le jasmin se développent au cœur, tandis que le bois de santal, le musc blanc et l’ambre prolongent la composition avec douceur.",
      meta_title: "Kenzie Vanilla 70 Volaré 100 ml | Parfum vanillé | ADURA",
      meta_description: "Kenzie Vanilla 70 de Volaré : un parfum unisexe aux notes de bergamote, fleur d’oranger, vanille de Madagascar, jasmin, santal et musc."
    },
    "khair-felicity" => {
      short_description: "Khair Felicity de Paris Corner mêle agrumes et fleurs à la rose, au jasmin, aux épices douces, à l’oud, l’ambre et au musc.",
      description: "Khair Felicity de Paris Corner est une eau de parfum unisexe florale aux accents boisés. Un accord floral lumineux et des agrumes ouvrent la composition. La rose, le jasmin et les épices douces se développent au cœur, avant un fond d’oud, de bois de santal, d’ambre et de musc plus enveloppant.",
      meta_title: "Khair Felicity Paris Corner 100 ml | Parfum floral | ADURA",
      meta_description: "Khair Felicity de Paris Corner : un parfum unisexe floral aux notes d’agrumes, rose, jasmin, épices douces, oud, ambre et musc."
    },
    "khair-pistachio" => {
      short_description: "Khair Pistachio de Paris Corner associe pistache, crème glacée et noisette à des fruits, fleurs, vanille, tonka et bois de santal.",
      description: "Khair Pistachio de Paris Corner est une eau de parfum unisexe gourmande. Pistache, crème glacée, bergamote, noisette et cardamome ouvrent la composition. Le muguet, la pivoine, le jasmin et des fruits apportent du relief au cœur, avant une base de barbe à papa, vanille, fève tonka, santal et cèdre.",
      meta_title: "Khair Pistachio Paris Corner 100 ml | Parfum gourmand | ADURA",
      meta_description: "Khair Pistachio de Paris Corner : un parfum unisexe gourmand aux notes de pistache, crème glacée, vanille, tonka, santal et cèdre."
    },
    "khamrah-qahwa" => {
      short_description: "Khamrah Qahwa de Lattafa mêle gingembre, cannelle et cardamome à un accord de café arabica, praliné, vanille et tonka.",
      description: "Khamrah Qahwa de Lattafa est une eau de parfum unisexe gourmande et épicée. Le gingembre, la cannelle et la cardamome donnent une ouverture chaleureuse. Le praliné, les fruits confits et les fleurs blanches composent le cœur, avant un fond de café arabica, fève tonka, musc, benjoin et vanille.",
      meta_title: "Khamrah Qahwa Lattafa 100 ml | Café, vanille & épices | ADURA",
      meta_description: "Khamrah Qahwa de Lattafa : un parfum unisexe gourmand aux notes de café arabica, praliné, cannelle, cardamome, vanille et tonka."
    },
    "lail-maleki-moroccan-blue" => {
      short_description: "Lail Maleki Moroccan Blue de Lattafa associe bergamote, safran et épices marocaines à des fleurs, des bois, l’ambre et le musc.",
      description: "Lail Maleki Moroccan Blue de Lattafa est une eau de parfum masculine boisée aux accents épicés. La bergamote, le safran et les épices marocaines donnent le départ. Le jasmin, la fleur d’oranger et le bois de cèdre composent le cœur, puis l’ambre, le patchouli, le santal et le musc prolongent le parfum.",
      meta_title: "Lail Maleki Moroccan Blue Lattafa 100 ml | Parfum boisé | ADURA",
      meta_description: "Lail Maleki Moroccan Blue de Lattafa : un parfum homme boisé aux notes de bergamote, safran, fleurs, cèdre, ambre, patchouli et musc."
    },
    "liam-blue-shine" => {
      short_description: "Liam Blue Shine de Lattafa associe bergamote, romarin et poivre à des notes marines, violette, musc, ambre et patchouli.",
      description: "Liam Blue Shine de Lattafa est une eau de parfum masculine musquée et aromatique. La bergamote, le romarin et le poivre ouvrent la composition avec une facette vive. Les notes marines et la violette occupent le cœur, tandis que le musc, l’ambre et le patchouli structurent un fond plus profond et boisé.",
      meta_title: "Liam Blue Shine Lattafa 100 ml | Parfum aromatique | ADURA",
      meta_description: "Liam Blue Shine de Lattafa : un parfum homme aromatique aux notes de bergamote, romarin, poivre, accord marin, violette, musc et ambre."
    },
    "mango-heaven" => {
      short_description: "Mango Heaven de Gulf Orchid mêle mangue, bergamote et pamplemousse à des fleurs, du caramel, du musc et du patchouli.",
      description: "Mango Heaven de Gulf Orchid est une eau de parfum unisexe tropicale. La mangue, la bergamote et le pamplemousse ouvrent le parfum sur une facette fruitée. Le bois de cachemire, la violette et les fleurs blanches composent le cœur, avant un fond de musc, caramel et patchouli qui apporte une touche plus profonde.",
      meta_title: "Mango Heaven Gulf Orchid 100 ml | Parfum tropical | ADURA",
      meta_description: "Mango Heaven de Gulf Orchid : un parfum unisexe tropical aux notes de mangue, bergamote, pamplemousse, fleurs blanches, caramel et musc."
    },
    "mayar-natural-intense" => {
      short_description: "Mayar Natural Intense de Lattafa associe figue, eau de coco, mandarine verte et melon à des fleurs, de la vanille, du musc et du santal.",
      description: "Mayar Natural Intense de Lattafa est une eau de parfum féminine fruitée et florale. La figue, l’eau de coco, la mandarine verte et le melon apportent une ouverture fraîche. Le lotus, le jasmin et le nénuphar composent le cœur, avant un fond de musc, bois de santal, vanille et ambroxan.",
      meta_title: "Mayar Natural Intense Lattafa 100 ml | Parfum fruité | ADURA",
      meta_description: "Mayar Natural Intense de Lattafa : un parfum femme fruité avec figue, eau de coco, melon, fleurs, vanille, musc et bois de santal."
    },
    "minya-coco-lush" => {
      short_description: "Minya Coco Lush de Paris Corner associe lait de coco, framboise et poire à des fleurs, un accord macaron, de l’ambroxan et du musc.",
      description: "Minya Coco Lush de Paris Corner est une eau de parfum unisexe gourmande aux facettes fruitées. Le lait de coco, la framboise et la poire ouvrent la composition. Le jasmin et le freesia forment le cœur floral, puis l’ambroxan, le macaron et le musc apportent une finition douce et légèrement pâtissière.",
      meta_title: "Minya Coco Lush Paris Corner 100 ml | Parfum gourmand | ADURA",
      meta_description: "Minya Coco Lush de Paris Corner : un parfum unisexe gourmand aux notes de lait de coco, framboise, poire, jasmin, macaron et musc."
    },
    "oud-mood" => {
      short_description: "Oud Mood de Lattafa mêle safran et rose à l’oud, la vanille, le caramel, l’ambre, le musc et le patchouli.",
      description: "Oud Mood de Lattafa est une eau de parfum unisexe boisée et ambrée. Le safran et la rose introduisent la composition avant un cœur de bois d’oud, vanille et caramel. L’ambre, le musc et le patchouli construisent ensuite un fond plus dense, où les facettes boisées et gourmandes se rencontrent.",
      meta_title: "Oud Mood Lattafa 100 ml | Parfum oud ambré | ADURA",
      meta_description: "Oud Mood de Lattafa : un parfum unisexe aux notes de safran, rose, oud, vanille, caramel, ambre, musc et patchouli."
    },
    "pina-colada-musk" => {
      short_description: "Piña Colada Musk de Gulf Orchid associe ananas et noix de coco à un accord de rhum blanc, fruits tropicaux, vanille et sucre de canne.",
      description: "Piña Colada Musk de Gulf Orchid est une eau de parfum unisexe tropicale et gourmande. L’ananas et la noix de coco ouvrent la composition avec une facette solaire. Le rhum blanc et les fruits tropicaux développent le cœur, puis la vanille et le sucre de canne prolongent le parfum dans un registre doux et exotique.",
      meta_title: "Piña Colada Musk Gulf Orchid 60 ml | Parfum tropical | ADURA",
      meta_description: "Piña Colada Musk de Gulf Orchid : un parfum unisexe tropical aux notes d’ananas, noix de coco, rhum blanc, vanille et sucre de canne."
    },
    "qaed-al-fursan" => {
      short_description: "Qaed Al Fursan de Lattafa associe ananas et safran à du caramel, du jasmin, de l’oud, de la vanille, du musc et de l’ambre.",
      description: "Qaed Al Fursan de Lattafa est une eau de parfum unisexe boisée et ambrée. L’ananas et le safran ouvrent la composition avec une facette fruitée et épicée. Le caramel, le jasmin et le bois d’oud composent le cœur, avant une base de vanille, musc et ambre qui apporte une signature plus douce.",
      meta_title: "Qaed Al Fursan Lattafa 90 ml | Parfum oud ambré | ADURA",
      meta_description: "Qaed Al Fursan de Lattafa : un parfum unisexe aux notes d’ananas, safran, caramel, jasmin, oud, vanille, musc et ambre."
    },
    "qaed-al-fursan-unlimited" => {
      short_description: "Qaed Al Fursan Unlimited de Lattafa mêle noix de coco, agrumes et ananas à des fleurs, de la vanille, du musc et du santal.",
      description: "Qaed Al Fursan Unlimited de Lattafa est une eau de parfum unisexe tropicale. La noix de coco, les agrumes et l’ananas ouvrent le parfum. L’ylang-ylang, le jasmin et le frangipanier composent le cœur floral, tandis que la vanille, le musc et le bois de santal apportent une finition douce et solaire.",
      meta_title: "Qaed Al Fursan Unlimited Lattafa 90 ml | Tropical | ADURA",
      meta_description: "Qaed Al Fursan Unlimited de Lattafa : un parfum unisexe tropical aux notes de coco, agrumes, ananas, ylang-ylang, vanille et santal."
    },
    "qimmah-for-women" => {
      short_description: "Qimmah For Women de Lattafa mêle amande et café à du jasmin, de la tubéreuse, de la tonka, du cacao, de la vanille et du santal.",
      description: "Qimmah For Women de Lattafa est une eau de parfum féminine gourmande et florale. L’amande et le café ouvrent la composition dans un registre chaleureux. Le jasmin, la tubéreuse et la fève tonka structurent le cœur, avant une base de cacao, vanille et bois de santal qui prolonge la signature douce du parfum.",
      meta_title: "Qimmah For Women Lattafa 100 ml | Parfum gourmand | ADURA",
      meta_description: "Qimmah For Women de Lattafa : un parfum femme gourmand aux notes d’amande, café, jasmin, tubéreuse, cacao, vanille et santal."
    },
    "shaghaf-vanilla-toffee" => {
      short_description: "Shaghaf Vanilla Toffee de Swiss Arabian associe caramel au beurre, café et pâtisserie aux noix à la vanille, la tonka, au sucre brun et au musc.",
      description: "Shaghaf Vanilla Toffee de Swiss Arabian est une eau de parfum unisexe gourmande. Le caramel au beurre et le café arabica donnent une ouverture pâtissière. La pâtisserie aux noix, le lait de dattes, la vanille et la cardamome composent le cœur, avant un fond de vanille de Madagascar, sucre brun, benjoin, tonka, musc et bois.",
      meta_title: "Shaghaf Vanilla Toffee Swiss Arabian 75 ml | ADURA",
      meta_description: "Shaghaf Vanilla Toffee de Swiss Arabian : un parfum gourmand aux notes de caramel, café, vanille, datte, sucre brun, tonka et musc."
    },
    "suqraat" => {
      short_description: "Suqraat de Lattafa associe bergamote et gingembre à la lavande, la feuille de violette, au musc, au santal et à l’ambre.",
      description: "Suqraat de Lattafa est une eau de parfum masculine boisée et aromatique. La bergamote et le gingembre donnent une ouverture fraîche et épicée. La lavande et la feuille de violette occupent le cœur, tandis que le musc, le bois de santal et l’ambre prolongent le parfum sur une base douce et boisée.",
      meta_title: "Suqraat Lattafa 100 ml | Parfum homme aromatique | ADURA",
      meta_description: "Suqraat de Lattafa : un parfum homme aromatique aux notes de bergamote, gingembre, lavande, violette, musc, santal et ambre."
    },
    "teriaq" => {
      short_description: "Teriaq de Lattafa mêle poivre rose, caramel, amande amère et abricot à des fleurs, du miel, de la vanille, du musc et du cuir.",
      description: "Teriaq de Lattafa est une eau de parfum unisexe gourmande aux facettes contrastées. Le poivre rose, le caramel, l’amande amère et l’abricot ouvrent la composition. Les fleurs blanches, la rose, la rhubarbe et le miel composent le cœur, avant un fond de vanille, musc, vétiver, labdanum et cuir.",
      meta_title: "Teriaq Lattafa 100 ml | Parfum gourmand | ADURA",
      meta_description: "Teriaq de Lattafa : un parfum unisexe gourmand aux notes de caramel, amande amère, abricot, miel, vanille, musc et cuir."
    },
    "vanilla-latte" => {
      short_description: "Vanilla Latte de Gulf Orchid associe café et mandarine à une vanille crémeuse, du bois de santal et du musc.",
      description: "Vanilla Latte de Gulf Orchid est une eau de parfum unisexe gourmande autour d’un accord café et vanille. Le café et la mandarine ouvrent la composition avec une facette vive. La vanille et une crème légère développent le cœur, puis le bois de santal et le musc installent un fond doux et boisé.",
      meta_title: "Vanilla Latte Gulf Orchid 100 ml | Café & vanille | ADURA",
      meta_description: "Vanilla Latte de Gulf Orchid : un parfum unisexe gourmand aux notes de café, mandarine, vanille crémeuse, santal et musc."
    },
    "velvet-oud" => {
      short_description: "Velvet Oud de Lattafa associe cardamome et bergamote à la violette, au patchouli, au daim, à l’oud, au musc ambré et à la mousse.",
      description: "Velvet Oud de Lattafa est une eau de parfum unisexe boisée et ambrée. La cardamome et la bergamote ouvrent la composition avec une facette épicée. La feuille de violette et le patchouli occupent le cœur, avant une base de daim, oud, musc ambré et mousse de chêne, plus sombre et texturée.",
      meta_title: "Velvet Oud Lattafa 100 ml | Parfum oud boisé | ADURA",
      meta_description: "Velvet Oud de Lattafa : un parfum unisexe boisé aux notes de cardamome, bergamote, violette, patchouli, daim, oud et musc ambré."
    },
    "yara-candy" => {
      short_description: "Yara Candy de Lattafa mêle mandarine verte et cassis à un bonbon pétillant à la fraise, du gardénia, de la vanille, du musc et de l’ambre.",
      description: "Yara Candy de Lattafa est une eau de parfum féminine fruitée et gourmande. La mandarine verte et le cassis ouvrent la composition. Un accord de bonbon pétillant à la fraise et le gardénia apportent une facette plus douce au cœur, avant le bois de santal, le sirop de vanille, le musc et l’ambre.",
      meta_title: "Yara Candy Lattafa 100 ml | Parfum fruité gourmand | ADURA",
      meta_description: "Yara Candy de Lattafa : un parfum femme fruité et gourmand aux notes de mandarine, cassis, fraise, gardénia, vanille, musc et ambre."
    },
    "yara-tous" => {
      short_description: "Yara Tous de Lattafa associe noix de coco, mangue et fruit de la passion à des fleurs, de la vanille, du musc et du cashmeran.",
      description: "Yara Tous de Lattafa est une eau de parfum féminine tropicale et florale. La noix de coco, la mangue et le fruit de la passion ouvrent la composition. Le jasmin, l’héliotrope et la fleur d’oranger développent le cœur, tandis que le cashmeran, la vanille et le musc apportent un fond doux et enveloppant.",
      meta_title: "Yara Tous Lattafa 100 ml | Parfum tropical | ADURA",
      meta_description: "Yara Tous de Lattafa : un parfum femme tropical aux notes de coco, mangue, fruit de la passion, jasmin, vanille, musc et cashmeran."
    }
  }.freeze

  def up
    product_class = Class.new(ActiveRecord::Base) do
      self.table_name = "products"
    end

    return if product_class.none?

    CONTENT.each do |slug, attributes|
      products = product_class.where(slug: slug)
      raise "Produit SEO introuvable ou dupliqué : #{slug}" unless products.count == 1

      products.update_all(attributes.merge(updated_at: Time.current))
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Les contenus éditoriaux précédents ne sont pas restaurés automatiquement."
  end
end
