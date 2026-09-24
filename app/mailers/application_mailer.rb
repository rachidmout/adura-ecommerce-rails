class ApplicationMailer < ActionMailer::Base
  ActionMailer::MailDeliveryJob.enqueue_after_transaction_commit = true

  helper ApplicationHelper

  default from: -> { ENV.fetch("MAILER_FROM", "bonjour@adura.local") }
  layout "mailer"

  def test_email(to)
    mail(
      to: to,
      subject: "Test e-mail ADURA",
      body: "Si tu reçois ce message, l'envoi SMTP ADURA fonctionne."
    )
  end
end
