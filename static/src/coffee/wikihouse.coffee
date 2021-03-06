# Public Domain (-) 2011 The WikiHouse Authors.
# See the WikiHouse UNLICENSE file for details.

window.wikihouse ?= {}

$(document).ready ->

  $progress = $ '#progress-indicator'
  $message = $ '.message', $progress
  
  $play_video = $ '#play-video'
  $play_video.click ->
      $splash_container = $ '#splash-container'
      $splash_container.hide()
      $vid_container = $ '#fitvid-container'
      $vid_container.html """
        <iframe src="//player.vimeo.com/video/52383144?title=0&amp;byline=0&amp;portrait=0&amp;color=ffffff&amp;autoplay=1"
            width="968" height="544" 
            frameborder="0" 
            webkitAllowFullScreen 
            mozallowfullscreen 
            allowFullScreen>
        </iframe>
      """
      $vid_container.fitVids()
      false
  
  
  # Setup the controls and methods for the upload page.
  if WIKIHOUSE_UPLOAD_PAGE?

    # Validate the submit design form, allowing the event to proceed if valid and
    # in the browser, or calling sketchup if valid an in sketchup.
    $form = $ '#submit-design-form'
    $form.bind 'submit', (event) ->
      data = $.parseQuery $form.serialize()
      valid = true
      # Title is required.
      $error = $('#design-title').closest('.field').find('.error')
      if not data.title
        $error.text _ 'You must provide a title'
        valid = false
      else
        $error.text ''
      # Description is required.
      $error = $('#design-description').closest('.field').find('.error')
      if not data.description
        $error.text _ 'You must provide a description.'
        valid = false
      else
        $error.text ''
      # URL must be valid if provided.
      $error = $('#design-url').closest('.field').find('.error')
      if data.url
        msg = _ 'Web link is not a valid URL.'
        hint = _ '(If you don\'t have a web link, leave the field blank)'
        try
          url = $.url data.url
        catch error
          $error.text "#{msg} #{hint}"
          valid = false
        if url? and not (url.attr('protocol') and '.' in url.attr('host'))
          $error.text "#{msg} #{hint}"
          valid = false
        else
          $error.text ''
      # Must select at least one series.
      $error = $('#design-series').closest('.field').find('.error')
      if not data.series or data.series.length is 0
        $error.text _ 'You must select at least one series.'
        valid = false
      else
        $error.text ''
      # If valid, either show processing state and call SketchUp
      # or submit via ajax.
      if valid
        if WIKIHOUSE_IS_SKETCHUP
          wikihouse.showProgress _ 'Processing SketchUp files ...'
          window.location = 'skp:process'
          return false
        else
          wikihouse.showProgress _ 'Uploading ...'
          return true

      return false



    # In the browser, handle the post response, via iframe load event (to make the
    # file uploads work without a page refresh).
    $frame = $ '#design-form-communication-frame'
    $frame.bind 'load', (event) ->
      data = null
      response = $frame.contents().find 'body'
      try
        data = $.parseJSON response.html()
      catch error
        if WIKIHOUSE_IS_SKETCHUP
          window.location = 'skp:uploaded@error'
        wikihouse.showError _ 'Upload failed. Please try again.'
      if data?
        if data.success?
          if WIKIHOUSE_IS_SKETCHUP
            window.location = 'skp:uploaded@success'
            setTimeout ->
                window.location.replace data.success
              , 1500
          else
            window.location.replace data.success
        else
          if WIKIHOUSE_IS_SKETCHUP
            window.location = 'skp:uploaded@error'
          else
            $form.action = data.upload_url
          wikihouse.showError data.error




    # In sketchup, post and handle the form using `$.ajax`.
    wikihouse.upload = ->
      # Show upload state.
      wikihouse.showProgress _ 'Uploading ...'
      url = $form.attr 'action'
      data = $form.serialize()
      $.ajax
        type: 'POST'
        url: url
        data: data
        dataType: 'json'
        success: (data) ->
          if data.success?
            if WIKIHOUSE_IS_SKETCHUP
              window.location = 'skp:uploaded@success'
              setTimeout ->
                window.location.replace data.success,
                1500
            else
              window.location.replace data.success
          else
            if WIKIHOUSE_IS_SKETCHUP
              window.location = 'skp:uploaded@error'
            else
              $form.action = data.upload_url
            wikihouse.showError data.error
        error: ->
          if WIKIHOUSE_IS_SKETCHUP
            window.location = 'skp:uploaded@error'
          wikihouse.showError _ 'Upload failed. Please try again.'



    # Call `wikihouse.showProgress(msg)` to trigger the in-progress state.
    wikihouse.showProgress = (msg) ->
      # Clear any validation error message.
      $form.find('.error').text ''
      # Show the progress indicator.
      $progress.height $form.height()
      $form.hide()
      $message.text msg
      $progress.show()


    # Call `wikihouse.showError(errmsg)` to show validation errors.
    wikihouse.showError = (errmsg) ->
      # Hide the progress indicator.
      $progress.hide()
      $form.show()
      # Display the error message.
      $error = $form.find('.error').first()
      $error.text errmsg


    # Inform SketchUp to preload input variables.
    if WIKIHOUSE_IS_SKETCHUP
      window.location = 'skp:load'


  # Setup the controls and methods for a download page.
  if WIKIHOUSE_DOWNLOAD_PAGE?

    # Ask the user to confirm before deleting.
    $delete_form = $ '.delete-form'
    $delete_form.bind 'submit', ->
      # If the user confirms, update the confirmation input to `true` and send
      # the form via XmlHttpRequest (so we can be sure the DELETE is respected).
      msg = _ 'Are you sure you want to delete this design from the WikiHouse library?'
      error_stub = _ 'There was an error.  Please try again.'
      if confirm msg
        $.ajax
          type: 'DELETE'
          url: "#{$delete_form.attr 'action'}?confirmed=true"
          dataType: 'json'
          success: (data) ->
            if data.success?
              window.location.replace data.success
            else
              alert "#{error_stub}\n#{data.error}"
          error: ->
            alert error_stub
      # Stop the event.
      return false


    if WIKIHOUSE_IS_SKETCHUP

      $download = $ '#design-download'
      if !$download.get(0)
        return

      $design = $ '#design'

      # Get the design's title and download urls.
      designTitle = $('#design-title').text()
      designURL = $download.attr 'href'
      designBase64 = $('#design-download-base64').attr 'href'
      isComponent = $download.attr 'rel'

      # Strip the filename from the URL.
      designURL = designURL.split "/"
      designURL = designURL.slice(0, designURL.length-1)
      designURL = designURL.join "/"

      # Call `wikihouse.showProgress(msg)` to trigger the in-progress state.
      wikihouse.showProgress = (msg) ->
        # Show the progress indicator.
        $progress.height '200px'
        $design.hide()
        $message.text msg
        $progress.show()

      wikihouse.hideProgress = ->
        # Show the progress indicator.
        $progress.hide()
        $design.show()

      wikihouse.download = (id, url) ->
        # Grab the model data over ajax.
        $.ajax
          type: 'GET'
          url: url
          dataType: 'text'
          success: (data) ->
            # Set the data into the hidden textarea.
            l = 1500000
            i = 0
            c = 0
            loop
              chunk = data.slice(c, c + l)
              if chunk.length is 0
                break
              $target = $('#design-download-data-' + i);
              $target.text(chunk)
              c = c + l
              i++
            $('#design-download-data').text(i)
            wikihouse.hideProgress()
            # Inform SketchUp of the available data.
            window.location = "skp:save@#{id}"
          error: ->
            wikihouse.hideProgress()
            # Inform SketchUp of the failed download.
            window.location = "skp:error@#{id}"



      # Call SketchUp when the download link is clicked.
      $download.click ->
        wikihouse.showProgress "Downloading WikiHouse Model ..."
        window.location = "skp:download@#{isComponent},#{designBase64},#{designURL},#{designTitle}"
        return false




