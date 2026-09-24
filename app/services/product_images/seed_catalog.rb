require "ripper"

module ProductImages
  # Relit uniquement le littéral `catalog = [ ... ]` de db/seeds.rb (slugs,
  # volumes, noms de fichiers images) sans jamais exécuter le reste du
  # fichier (ShopSetting, AdminUser, produits, commandes de démo...). Ça
  # évite de dupliquer cette liste ailleurs — donc pas de risque qu'une
  # copie diverge de la source réelle — sans rien exécuter de db/seeds.rb.
  module SeedCatalog
    class ParseError < StandardError; end

    def self.load(path: Rails.root.join("db/seeds.rb"))
      program = Ripper.sexp(File.read(path))
      raise ParseError, "catalog introuvable dans #{path}" unless program

      assignment = Array(program[1]).find { |node| catalog_assignment?(node) }
      raise ParseError, "catalog introuvable dans #{path}" unless assignment

      parse_literal(assignment[2])
    end

    def self.catalog_assignment?(node)
      node&.first == :assign &&
        node.dig(1, 0) == :var_field &&
        node.dig(1, 1, 0) == :@ident &&
        node.dig(1, 1, 1) == "catalog"
    end

    def self.parse_literal(node)
      case node&.first
      when :array
        Array(node[1]).map { |entry| parse_literal(entry) }
      when :hash
        parse_hash(node)
      when :string_literal
        parse_string(node)
      when :@int
        node[1].to_i
      when :var_ref
        parse_keyword(node)
      else
        raise ParseError, "valeur non autorisée dans catalog"
      end
    end

    def self.parse_hash(node)
      associations = node[1]
      return {} unless associations

      unless associations.first == :assoclist_from_args
        raise ParseError, "hash non autorisé dans catalog"
      end

      Array(associations[1]).each_with_object({}) do |association, hash|
        unless association.first == :assoc_new && association.dig(1, 0) == :@label
          raise ParseError, "clé non autorisée dans catalog"
        end

        hash[association[1][1].delete_suffix(":").to_sym] = parse_literal(association[2])
      end
    end

    def self.parse_string(node)
      content = node[1]
      return "" unless content

      unless content.first == :string_content && content.drop(1).all? { |part| part.first == :@tstring_content }
        raise ParseError, "chaîne non autorisée dans catalog"
      end

      content.drop(1).map { |part| part[1] }.join
    end

    def self.parse_keyword(node)
      case node.dig(1, 1)
      when "true" then true
      when "false" then false
      when "nil" then nil
      else
        raise ParseError, "valeur non autorisée dans catalog"
      end
    end

    private_class_method :catalog_assignment?, :parse_literal, :parse_hash, :parse_string, :parse_keyword
  end
end
