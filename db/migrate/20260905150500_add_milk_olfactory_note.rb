class AddMilkOlfactoryNote < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO olfactory_notes (name, slug, active, created_at, updated_at)
      SELECT 'Lait', 'lait', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      WHERE NOT EXISTS (
        SELECT 1 FROM olfactory_notes WHERE slug = 'lait'
      )
    SQL

    # Les anciens seeds renseignaient automatiquement "moderate" pour
    # l'intensité, même lorsque cette donnée n'avait pas été vérifiée.
    # On ne nettoie que la signature exacte de ces profils générés afin de
    # conserver toute valeur enrichie manuellement par la suite.
    execute <<~SQL
      UPDATE perfume_profiles
      SET intensity_level = NULL,
          updated_at = CURRENT_TIMESTAMP
      WHERE intensity_level = 'moderate'
        AND longevity_level IS NULL
        AND sillage_level IS NULL
        AND season_codes = ARRAY[]::text[]
        AND occasion_codes = ARRAY['daily', 'gift']::text[]
    SQL
  end

  def down
    execute <<~SQL
      DELETE FROM olfactory_notes
      WHERE slug = 'lait'
        AND NOT EXISTS (
          SELECT 1 FROM product_olfactory_notes
          WHERE product_olfactory_notes.olfactory_note_id = olfactory_notes.id
        )
    SQL
  end
end
