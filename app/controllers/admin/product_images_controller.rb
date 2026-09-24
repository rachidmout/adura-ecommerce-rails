module Admin
  class ProductImagesController < BaseController
    before_action :set_product
    before_action :set_image, only: %i[update destroy set_primary move_up move_down]

    def create
      files = Array(params[:images]).reject(&:blank?)
      if files.empty?
        redirect_to edit_admin_product_path(@product), alert: "Choisissez au moins un fichier."
        return
      end

      base_position = (@product.product_images.maximum(:position) || -1) + 1
      files.each_with_index do |file, index|
        image = @product.product_images.create!(
          alt_text: params[:alt_text].presence || "Photo #{@product.name}",
          product_variant_id: params[:product_variant_id].presence,
          position: base_position + index
        )
        image.file.attach(file)
      end
      redirect_to edit_admin_product_path(@product), notice: files.size > 1 ? "Images ajoutées." : "Image ajoutée."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to edit_admin_product_path(@product), alert: error.record.errors.full_messages.to_sentence
    end

    def update
      if @image.update(alt_text: params[:image][:alt_text])
        redirect_to edit_admin_product_path(@product), notice: "Texte alternatif mis à jour."
      else
        redirect_to edit_admin_product_path(@product), alert: @image.errors.full_messages.to_sentence
      end
    end

    def destroy
      @image.file.purge
      @image.destroy!
      promote_new_primary_if_needed
      redirect_to edit_admin_product_path(@product), notice: "Image supprimée."
    end

    def set_primary
      Product.transaction do
        @product.product_images.update_all(primary: false)
        @image.update!(primary: true)
      end
      redirect_to edit_admin_product_path(@product), notice: "Image principale mise à jour."
    end

    def move_up
      swap_with(-1)
    end

    def move_down
      swap_with(1)
    end

    private

    def set_product
      @product = Product.find_by!(slug: params[:product_id])
    end

    def set_image
      @image = @product.product_images.find(params[:id])
    end

    # Échange la position de l'image avec sa voisine directe dans la liste
    # triée — pas besoin d'un algorithme de réordonnancement plus complexe
    # puisque les boutons ▲▼ ne déplacent une image que d'un cran à la fois.
    def swap_with(offset)
      ordered = @product.product_images.order(:position, :id).to_a
      index = ordered.index(@image)
      target_index = index + offset if index
      neighbor = ordered[target_index] if target_index&.between?(0, ordered.size - 1)

      if neighbor
        image_position = @image.position
        Product.transaction do
          @image.update!(position: neighbor.position)
          neighbor.update!(position: image_position)
        end
      end

      redirect_to edit_admin_product_path(@product)
    end

    # Une image principale est requise pour publier un produit (voir
    # Product#published_product_is_complete) : si on vient de supprimer
    # l'image qui portait ce rôle, on le repasse automatiquement à celle qui
    # reste en première position plutôt que de laisser la galerie sans image
    # principale.
    def promote_new_primary_if_needed
      return if @product.product_images.exists?(primary: true)

      @product.product_images.order(:position, :id).first&.update!(primary: true)
    end
  end
end
