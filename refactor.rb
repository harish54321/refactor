# Controller

class People < ActionController::Base

	# ... Other REST actions

	def create
		@person = Person.new(params[:person])
		@count  = Person.count + 1

		slug = "ABC123#{Time.now.to_i}1239827#{rand(10000)}" 
		@person.slug = slug
		@person.admin = false

		if @count.odd?
			@person.handle = "UnicornRainbows" + @count.to_s
			@person.team   = "UnicornRainbows"
		else
			@person.handle = "LaserScorpions" + @count.to_s
			@person.team   = "LaserScorpions"
		end

		if @person.save
			Emails.validate_email(@person).deliver
			@admins = Person.admins
			Emails.admin_new_user(@admins, @person).deliver
			redirect_to @person, :notice => "Account added!"
		else
			render :new
		end
	end

# This validateEmail action have not been used , but it seems to work for validating the user by admin.
# So, I hope when admin accepted the person as a validate user then this method will trigger. otherwise we can remove this action 

	def validateEmail
		@user = Person.find_by_slug(params[:slug])
		if @user.present?
			@user.validated = true
			@user.save
			Rails.logger.info "USER: User ##{@person.id} validated email successfully."
			@admins = Person.admins
			Emails.admin_user_validated(@admins, user)
			Emails.welcome(@user).deliver!
		end
	end

end


# Model

class Person < ActiveRecord::Base
	attr_accessible :first_name, :last_name, :email, :admin, :slug, :validated, :handle, :team
	scope :admins -> { where(:admin => true) }
end


# Mailer

class Emails < ActionMailer::Base

# This  welcome action depends on validateEmail action in controller.
  def welcome(person)
      @person = person
      mail to: @person, from: 'foo@example.com'
	end

  def validate_email(person)
      @person = person
      mail to: @person, from: 'foo@example.com'
  end

# This admin_user_validate action depends on validateEmail action in controller.

	def admin_user_validated(admins, user)
	    @admins = admins.collect {|a| a.email } rescue []
	    @user = user
	    mail to: @admins, from: 'foo@example.com'
	end

  def admin_new_user(admins, user)
		@admins = admins.collect {|a| a.email } rescue []
		@user = user
		mail to: @admins, from: 'foo@example.com'
  end

  def admin_removing_unvalidated_users(admins, users)
		@admins = admins.collect {|a| a.email } rescue []
		@users = users
		mail to: admins, from: 'foo@example.com'
  end

end


# Rake Task

namespace :accounts do
	
	desc "Remove accounts where the email was never validated and it is over 30 days old"
	task :remove_unvalidated do
		@people = Person.where('created_at < ? AND validated = ?', Time.now - 30.days, false)
		Emails.admin_removing_unvalidated_users(Person.admins, @people).deliver
		@people.each do |person|
			Rails.logger.info "Removing unvalidated user #{person.email}"
			person.destroy
		end
	end
	
end
