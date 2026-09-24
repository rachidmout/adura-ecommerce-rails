class AddSeoFieldsToOlfactoryFamilies < ActiveRecord::Migration[8.1]
  def change
    add_column :olfactory_families, :meta_title, :string
    add_column :olfactory_families, :meta_description, :string
  end
end
