#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class PeopleController < ApplicationController
  before_filter :authenticate_user!

  respond_to :html
  respond_to :json, :only => [:index, :show]

  def index
    @aspect = :search
    @people = Person.search(params[:q]).paginate :page => params[:page], :per_page => 25, :order => 'created_at DESC'
    respond_with @people
  end

  def show
    @aspect = :profile

    @person = Person.find(params[:id].to_id)

    if @person
      @profile = @person.profile
      @contact = current_user.contact_for(@person)
      @is_contact = @person != current_user.person && @contact

      if @contact
        @aspects_with_person = @contact.aspects
      else
        @pending_request = current_user.pending_requests.find_by_person_id(@person.id)
      end

      @posts = current_user.visible_posts(:person_id => @person.id).paginate :page => params[:page], :order => 'created_at DESC'
      respond_with @person
    else
      flash[:error] = I18n.t 'people.show.does_not_exist'
      redirect_to people_path
    end
  end

  def destroy
    current_user.unfriend(current_user.visible_person_by_id(params[:id]))
    respond_with :location => root_url
  end

  def edit
    @aspect  = :person_edit
    @person  = current_user.person
    @profile = @person.profile
  end

  def update
    # convert date selector into proper timestamp
    
    if birthday = params[:date]
      unless [:month, :day, :year].any?{|x| birthday[x].blank?} 
        params[:person][:profile][:birthday] ||= Date.parse("#{birthday[:year]}-#{birthday[:month]}-#{birthday[:day]}")
      end
    end

    # upload and set new profile photo
    params[:person][:profile] ||= {}
    if params[:person][:profile][:image].present?
      raw_image = params[:person][:profile].delete(:image)
      params[:profile_image_hash] = { :user_file => raw_image, :to => "all" }

      photo = current_user.post(:photo, params[:profile_image_hash])
      params[:person][:profile][:image_url] = photo.url(:thumb_medium)
    end

    if current_user.update_profile params[:person][:profile]
      flash[:notice] = I18n.t 'people.update.updated'
    else
      flash[:error] = I18n.t 'people.update.failed'
    end

    if params[:getting_started]
      redirect_to getting_started_path(:step => params[:getting_started].to_i+1)
    else
      redirect_to edit_person_path
    end
  end
end
