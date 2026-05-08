class BaseService
  attr_accessor :result

  def valid?
    errors.blank?
  end

  def errors
    @errors ||= []
  end

  private

  def logger
    Rails.logger
  end

  def cache
    Rails.cache
  end
end
