module Admin
  # Les familles sont déjà seedées (6 au total) : pas de création/suppression
  # ici, seulement l'édition du contenu éditorial et SEO.
  class OlfactoryFamiliesController < BaseController
    before_action :set_olfactory_family, only: %i[edit update]

    def index
      @olfactory_families = OlfactoryFamily.order(:name)
    end

    def edit
    end

    def update
      if @olfactory_family.update(olfactory_family_params)
        redirect_to admin_olfactory_families_path, notice: "Famille enregistrée."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_olfactory_family
      @olfactory_family = OlfactoryFamily.find(params[:id])
    end

    def olfactory_family_params
      params.require(:olfactory_family).permit(:description, :meta_title, :meta_description)
    end
  end
end
