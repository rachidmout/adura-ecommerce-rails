module Admin
  class MarketingVideoJobsController < BaseController
    def index
      @marketing_video_jobs = MarketingVideoJob.order(created_at: :desc)
    end

    def show
      @marketing_video_job = MarketingVideoJob.find(params[:id])
    end

    def approve
      @marketing_video_job = MarketingVideoJob.find(params[:id])
      @marketing_video_job.approve!

      redirect_to admin_marketing_video_job_path(@marketing_video_job), notice: "La demande vidéo a été validée."
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_marketing_video_job_path(@marketing_video_job), alert: "Cette demande vidéo a déjà été traitée."
    end

    def reject
      @marketing_video_job = MarketingVideoJob.find(params[:id])
      @marketing_video_job.reject!

      redirect_to admin_marketing_video_job_path(@marketing_video_job), notice: "La demande vidéo a été rejetée."
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_marketing_video_job_path(@marketing_video_job), alert: "Cette demande vidéo a déjà été traitée."
    end

    def generate
      @marketing_video_job = MarketingVideoJob.find(params[:id])
      unless MarketingVideos::HiggsfieldClient.enabled?
        redirect_to admin_marketing_video_job_path(@marketing_video_job), alert: "La génération Higgsfield est désactivée."
        return
      end

      unless MarketingVideos::HiggsfieldClient.configured?
        redirect_to admin_marketing_video_job_path(@marketing_video_job), alert: "Les identifiants ou le modèle Higgsfield ne sont pas configurés correctement."
        return
      end

      @marketing_video_job.start_generation!
      MarketingVideoGenerationJob.perform_later(@marketing_video_job.id)

      redirect_to admin_marketing_video_job_path(@marketing_video_job), notice: "La génération Higgsfield a été mise en file d’attente."
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_marketing_video_job_path(@marketing_video_job), alert: "Cette demande vidéo ne peut pas être générée dans son état actuel."
    rescue ActiveJob::EnqueueError
      @marketing_video_job.mark_generation_failed!("Impossible de mettre la génération Higgsfield en file d’attente.")
      redirect_to admin_marketing_video_job_path(@marketing_video_job), alert: "La génération Higgsfield n’a pas pu être mise en file d’attente."
    end

    def destroy
      @marketing_video_job = MarketingVideoJob.find(params[:id])
      @marketing_video_job.destroy_by_admin!

      redirect_to admin_marketing_video_jobs_path, notice: "La demande vidéo a été supprimée."
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_marketing_video_job_path(@marketing_video_job), alert: "Cette demande vidéo ne peut pas être supprimée dans son état actuel."
    end
  end
end
