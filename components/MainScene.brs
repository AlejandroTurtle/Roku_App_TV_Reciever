sub init()
    print "RokuCaster: MainScene inicializada"
    m.background = m.top.findNode("background")
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.canvas = m.top.findNode("canvas")
    m.statusLabel = m.top.findNode("statusLabel")
    m.detailLabel = m.top.findNode("detailLabel")
    m.playlistTask = m.top.findNode("playlistTask")
    m.playbackStatusTask = m.top.findNode("playbackStatusTask")
    m.playbackStatusTimer = m.top.findNode("playbackStatusTimer")
    m.progressOverlayTimer = m.top.findNode("progressOverlayTimer")
    m.continuousSeekTimer = m.top.findNode("continuousSeekTimer")
    m.seekCommitTimer = m.top.findNode("seekCommitTimer")
    m.seekTargetTimer = m.top.findNode("seekTargetTimer")
    m.playbackStatusSettleTimer = m.top.findNode("playbackStatusSettleTimer")
    m.playlistOverlay = m.top.findNode("playlistOverlay")
    m.playlistOverlayTitle = m.top.findNode("playlistOverlayTitle")
    m.playlistOverlaySubtitle = m.top.findNode("playlistOverlaySubtitle")
    m.playlistOverlayFooter = m.top.findNode("playlistOverlayFooter")
    m.playlistRows = m.top.findNode("playlistRows")
    m.playlistSelectionFont = m.top.findNode("playlistSelectionFontTemplate").font
    m.playlistRowNodes = []
    m.playbackNotice = m.top.findNode("playbackNotice")
    m.playbackNoticeLabel = m.top.findNode("playbackNoticeLabel")
    m.progressOverlay = m.top.findNode("progressOverlay")
    m.progressActionLabel = m.top.findNode("progressActionLabel")
    m.progressTimeLabel = m.top.findNode("progressTimeLabel")
    m.progressBarFill = m.top.findNode("progressBarFill")
    m.top.observeField("screenSize", "updateLayout")
    m.videoPlayer.observeField("state", "onPlaybackStateChanged")
    m.videoPlayer.observeField("contentIndex", "onPlaybackIndexChanged")
    m.playlistTask.observeField("result", "onPlaylistManifestChanged")
    m.playlistTask.observeField("error", "onPlaylistManifestChanged")
    m.playbackStatusTimer.observeField("fire", "onPlaybackStatusTimer")
    m.progressOverlayTimer.observeField("fire", "hidePlaybackProgress")
    m.continuousSeekTimer.observeField("fire", "onContinuousSeekTimer")
    m.seekCommitTimer.observeField("fire", "commitPendingSeek")
    m.seekTargetTimer.observeField("fire", "clearPendingSeekTarget")
    m.playbackStatusSettleTimer.observeField("fire", "onPlaybackStatusSettle")
    m.playbackStatusTask.observeField("result", "onPlaybackStatusPosted")

    m.isPlaying = false
    m.isPlaylist = false
    m.currentVideoIndex = 0
    m.selectedPlaylistIndex = 0
    m.playlistItems = []
    m.orderedOriginalIndexes = []
    m.originalToInternal = {}
    m.playbackStatusUrl = ""
    m.playbackStatusPending = false
    m.playbackErrorCode = 0
    m.playbackErrorCategory = ""
    m.playbackErrorMessage = ""
    m.playbackErrorDetails = ""
    m.playbackAudioFormat = ""
    m.resumeAppliedIndex = -1
    m.continuousSeekDirection = 0
    m.continuousSeekTarget = 0
    m.pendingSeekPosition = 0
    m.hasPendingSeek = false
    m.pendingStartIndex = -1
    m.pendingStartPosition = 0
    m.isPlaylistTransitionPending = false
    m.playbackStatusSuppressed = false
    m.requestedStartIndex = 0
    m.playlistOverlay.visible = false
    m.currentPlaylistRequestId = 0
    initializePlaylistRows()
    m.top.setFocus(true)
    updateLayout()
end sub

sub updateLayout()
    screenSize = m.top.screenSize
    if screenSize = invalid
        screenWidth = 1280
        screenHeight = 720
    else
        screenWidth = screenSize[0]
        screenHeight = screenSize[1]
        if screenWidth <= 0 or screenHeight <= 0
            screenWidth = 1280
            screenHeight = 720
        end if
    end if

    scale = screenWidth / 1920
    heightScale = screenHeight / 1080
    if heightScale < scale then scale = heightScale
    m.canvas.scale = [scale, scale]
    m.canvas.translation = [(screenWidth - (1920 * scale)) / 2, (screenHeight - (1080 * scale)) / 2]
    m.playlistOverlay.scale = [scale, scale]
    m.playlistOverlay.translation = [(screenWidth - (1920 * scale)) / 2, (screenHeight - (1080 * scale)) / 2]
    m.playbackNotice.scale = [scale, scale]
    m.playbackNotice.translation = [(screenWidth - (1920 * scale)) / 2, (screenHeight - (1080 * scale)) / 2]
    m.progressOverlay.scale = [scale, scale]
    m.progressOverlay.translation = [(screenWidth - (1920 * scale)) / 2, (screenHeight - (1080 * scale)) / 2]
    m.background.width = screenWidth
    m.background.height = screenHeight
    m.videoPlayer.width = screenWidth
    m.videoPlayer.height = screenHeight
end sub

function receiveExternalCommand(parameters as Object) as Boolean
    if parameters = invalid then return false

    action = LCase(getParameter(parameters, "action"))
    command = LCase(getParameter(parameters, "command"))
    statusUrl = getParameter(parameters, "statusUrl")
    if statusUrl <> "" then m.playbackStatusUrl = statusUrl

    if action = "control" or command = "pause" or command = "play" or command = "resume" or command = "next" or command = "previous" or command = "select" or command = "forward" or command = "rewind" or command = "seek"
        handlePlaybackCommand(command, getParameter(parameters, "index"), getParameter(parameters, "position"))
        return true
    end if

    if action = "stop" or command = "stop"
        stopPlayback("Aguardando o próximo vídeo enviado do celular.")
        return true
    end if

    startIndex = getParameter(parameters, "startIndex")
    if startIndex <> "" then m.requestedStartIndex = Int(Val(startIndex))

    playlistUrl = getParameter(parameters, "playlistUrl")
    if playlistUrl = ""
        contentId = getParameter(parameters, "contentId")
        mediaType = LCase(getParameter(parameters, "mediaType"))
        if mediaType = "shortformvideo" and isPlaylistManifestUrl(contentId)
            playlistUrl = contentId
        end if
    end if
    if playlistUrl <> ""
        startPlaylistFromUrl(playlistUrl)
        return true
    end if

    playlistJson = getParameter(parameters, "playlist")
    if playlistJson <> ""
        playlistItems = parsePlaylist(playlistJson)
        if playlistItems = invalid
            showReceiverMessage("PLAYLIST INVÁLIDA", "Envie uma lista JSON com pelo menos um vídeo e URLs HTTP ou HTTPS.")
            return true
        end if

        startPlaylist(playlistItems)
        return true
    end if

    videoUrl = getParameter(parameters, "url")
    if videoUrl = "" then videoUrl = getParameter(parameters, "contentid")
    if videoUrl = ""
        showReceiverMessage("AGUARDANDO ENVIO", "O comando chegou sem uma URL de vídeo. Envie um link HTTP ou HTTPS direto para a mídia.")
        return true
    end if

    if not isSupportedVideoUrl(videoUrl)
        showReceiverMessage("LINK NÃO SUPORTADO", "O vídeo precisa estar disponível em um endereço HTTP ou HTTPS acessível pela TV.")
        return true
    end if

    videoTitle = getParameter(parameters, "title")
    if videoTitle = "" then videoTitle = "Vídeo enviado do celular"

    streamFormat = getParameter(parameters, "streamFormat")
    if streamFormat = "" then streamFormat = getParameter(parameters, "format")
    if streamFormat = "" then streamFormat = inferStreamFormat(videoUrl)
    streamFormat = LCase(streamFormat)

    content = CreateObject("roSGNode", "ContentNode")
    content.url = videoUrl
    content.title = videoTitle
    content.streamFormat = streamFormat
    directItem = { url: videoUrl, title: videoTitle, streamFormat: streamFormat }
    m.playlistItems = [directItem]
    m.orderedOriginalIndexes = [0]
    m.currentVideoIndex = 0
    m.selectedPlaylistIndex = 0
    m.originalToInternal = { "0": 0 }
    m.pendingStartIndex = 0
    m.pendingStartPosition = 0
    m.isPlaylistTransitionPending = true
    m.playbackStatusSuppressed = true
    startPlayback(content, false, videoTitle)
    return true
end function

function parsePlaylist(playlistJson as String) as Object
    parsedItems = ParseJSON(playlistJson)
    if type(parsedItems) <> "roArray" then return invalid
    if parsedItems.Count() = 0 then return invalid

    playlistItems = CreateObject("roArray", 0, true)
    for each parsedItem in parsedItems
        if type(parsedItem) <> "roAssociativeArray" then return invalid

        itemUrl = getParameter(parsedItem, "url")
        if itemUrl = "" then itemUrl = getParameter(parsedItem, "contentid")
        if not isSupportedVideoUrl(itemUrl) then return invalid

        itemTitle = getParameter(parsedItem, "title")
        if itemTitle = "" then itemTitle = "Vídeo da playlist"

        itemFormat = getParameter(parsedItem, "streamFormat")
        if itemFormat = "" then itemFormat = getParameter(parsedItem, "format")
        if itemFormat = "" then itemFormat = inferStreamFormat(itemUrl)

        normalizedItem = {}
        normalizedItem.url = itemUrl
        normalizedItem.title = itemTitle
        normalizedItem.streamFormat = LCase(itemFormat)
        normalizedItem.resumePosition = Int(Val(getParameter(parsedItem, "resumePosition")))
        if normalizedItem.resumePosition < 0 then normalizedItem.resumePosition = 0
        normalizedItem.durationSeconds = Int(Val(getParameter(parsedItem, "durationSeconds")))
        if normalizedItem.durationSeconds < 0 then normalizedItem.durationSeconds = 0
        playlistItems.Push(normalizedItem)
    end for

    return playlistItems
end function

sub startPlaylistFromUrl(playlistUrl as String)
    if not isSupportedVideoUrl(playlistUrl)
        showReceiverMessage("LINK NÃO SUPORTADO", "O manifesto da playlist precisa estar em um endereço HTTP ou HTTPS acessível pela TV.")
        return
    end if

    if LCase(m.playlistTask.state) = "run" then m.playlistTask.control = "STOP"
    m.currentPlaylistRequestId = m.currentPlaylistRequestId + 1
    m.playlistTask.error = ""
    m.playlistTask.result = ""
    m.playlistTask.requestId = m.currentPlaylistRequestId
    m.playlistTask.url = playlistUrl
    if m.isPlaying then m.videoPlayer.control = "stop"
    m.statusLabel.text = "CARREGANDO PLAYLIST"
    m.detailLabel.text = "Buscando a lista no celular…"
    m.canvas.visible = true
    m.videoPlayer.visible = false
    m.isPlaying = false
    m.playlistTask.control = "RUN"
end sub

sub onPlaylistManifestChanged(event as Object)
    taskNode = event.GetRoSGNode()
    if taskNode.requestId <> m.currentPlaylistRequestId then return

    changedField = event.GetField()
    if changedField = "error"
        if taskNode.error <> ""
            print "RokuCaster playlist error: "; taskNode.error
            showReceiverMessage("FALHA AO ABRIR PLAYLIST", "Não foi possível acessar o celular. Confira se os dois aparelhos estão na mesma rede Wi-Fi.")
        end if
        return
    end if

    manifestJson = taskNode.result
    if manifestJson = "" then return
    playlistItems = parsePlaylist(manifestJson)
    if playlistItems = invalid
        showReceiverMessage("PLAYLIST INVÁLIDA", "O manifesto recebido não contém uma lista válida de vídeos.")
        return
    end if

    startPlaylist(playlistItems)
end sub

function isSupportedVideoUrl(videoUrl as String) as Boolean
    normalizedUrl = LCase(videoUrl)
    return Left(normalizedUrl, 7) = "http://" or Left(normalizedUrl, 8) = "https://"
end function

function isPlaylistManifestUrl(candidateUrl as String) as Boolean
    normalizedUrl = LCase(candidateUrl)
    if Left(normalizedUrl, 7) <> "http://" and Left(normalizedUrl, 8) <> "https://" then return false
    return Instr(1, normalizedUrl, "/playlist/") > 0 and Instr(1, normalizedUrl, ".json") > 0
end function

sub startPlaylist(playlistItems as Object)
    m.playlistItems = playlistItems
    m.orderedOriginalIndexes = []
    itemCount = playlistItems.Count()
    startIndex = m.requestedStartIndex
    if startIndex < 0 or startIndex >= itemCount then startIndex = 0
    m.requestedStartIndex = 0
    m.selectedPlaylistIndex = startIndex
    m.originalToInternal = {}
    m.pendingStartIndex = startIndex
    m.pendingStartPosition = playlistItems[startIndex].resumePosition
    if m.pendingStartPosition = invalid then m.pendingStartPosition = 0
    m.isPlaylistTransitionPending = true
    m.playbackStatusSuppressed = true

    if itemCount = 1
        playlistItem = playlistItems[startIndex]
        m.currentVideoIndex = startIndex
        m.orderedOriginalIndexes.Push(startIndex)
        m.originalToInternal[startIndex.ToStr()] = 0
        content = CreateObject("roSGNode", "ContentNode")
        content.url = playlistItem.url
        content.title = playlistItem.title
        content.streamFormat = playlistItem.streamFormat
        startPlayback(content, false, playlistItem.title)
        return
    end if

    playlistContent = CreateObject("roSGNode", "ContentNode")
    for offset = 0 to itemCount - 1
        originalIndex = (startIndex + offset) mod itemCount
        playlistItem = playlistItems[originalIndex]
        m.orderedOriginalIndexes.Push(originalIndex)
        m.originalToInternal[originalIndex.ToStr()] = offset
        contentItem = playlistContent.CreateChild("ContentNode")
        contentItem.url = playlistItem.url
        contentItem.title = playlistItem.title
        contentItem.streamFormat = playlistItem.streamFormat
    end for

    m.currentVideoIndex = startIndex
    startPlayback(playlistContent, true, playlistItems[startIndex].title)
end sub

sub startPlayback(content as Object, isPlaylist as Boolean, displayTitle as String)
    stopContinuousSeek()
    m.seekCommitTimer.control = "stop"
    m.seekTargetTimer.control = "stop"
    m.hasPendingSeek = false
    m.playbackErrorCode = 0
    m.playbackErrorCategory = ""
    m.playbackErrorMessage = ""
    m.playbackErrorDetails = ""
    m.playbackAudioFormat = ""
    if m.isPlaying then m.videoPlayer.control = "stop"

    m.isPlaylist = isPlaylist
    m.resumeAppliedIndex = -1
    m.playlistOverlay.visible = false
    m.playbackNotice.visible = false
    m.progressOverlay.visible = false
    m.videoPlayer.content = content
    m.videoPlayer.contentIsPlaylist = isPlaylist
    m.videoPlayer.loop = false
    m.statusLabel.text = "CONECTANDO À PLAYLIST"
    if not isPlaylist then m.statusLabel.text = "CONECTANDO AO VÍDEO"
    m.detailLabel.text = displayTitle
    m.canvas.visible = false
    m.videoPlayer.visible = true
    m.isPlaying = true
    m.top.setFocus(true)
    m.videoPlayer.control = "play"
    if m.playbackStatusUrl <> ""
        m.playbackStatusTimer.control = "start"
        reportPlaybackStatus()
    end if
end sub

sub onPlaybackStateChanged()
    playbackState = LCase(m.videoPlayer.state)
    if playbackState = "playing" then applyResumePosition()
    if playbackState = "error" then capturePlaybackError()
    if playbackState = "paused"
        showPlaybackNotice("PAUSADO  ·  ←/→ 10s  ·  << anterior  ·  >> próximo  ·  ↑ lista")
    else if playbackState = "playing"
        m.playbackNotice.visible = false
    end if
    reportPlaybackStatus()

    if playbackState = "error"
        print "RokuCaster video error: "; m.videoPlayer.errorMsg
        if m.videoPlayer.errorInfo <> invalid then print "RokuCaster video error details: "; FormatJSON(m.videoPlayer.errorInfo)
        errorMessage = "Falha na reprodução: " + m.playbackErrorMessage
        if m.playbackErrorCode <> 0 then errorMessage = "Erro Roku " + m.playbackErrorCode.ToStr() + ": " + m.playbackErrorMessage
        stopPlayback(errorMessage)
    else if playbackState = "finished"
        stopPlayback("Vídeo finalizado. A TV está pronta para receber outro.")
    end if
end sub

sub capturePlaybackError()
    errorCode = m.videoPlayer.errorCode
    if errorCode = invalid then errorCode = 0
    m.playbackErrorCode = errorCode

    errorMessage = m.videoPlayer.errorMsg
    if errorMessage = invalid then errorMessage = ""
    errorDetails = m.videoPlayer.errorStr
    if errorDetails = invalid then errorDetails = ""

    errorInfo = m.videoPlayer.errorInfo
    m.playbackErrorCategory = ""
    if errorInfo <> invalid
        if errorInfo.category <> invalid then m.playbackErrorCategory = LCase(errorInfo.category)
        if errorDetails = "" and errorInfo.dbgmsg <> invalid then errorDetails = errorInfo.dbgmsg
    end if

    if errorMessage = "" then errorMessage = errorDetails
    if errorMessage = "" then errorMessage = "A Roku não informou o motivo da falha."
    m.playbackErrorMessage = errorMessage
    m.playbackErrorDetails = errorDetails
end sub

sub onPlaybackIndexChanged()
    m.resumeAppliedIndex = -1
    internalIndex = m.videoPlayer.contentIndex
    if internalIndex <> invalid and m.orderedOriginalIndexes <> invalid
        if internalIndex >= 0 and internalIndex < m.orderedOriginalIndexes.Count()
            originalIndex = m.orderedOriginalIndexes[internalIndex]
            if originalIndex <> m.currentVideoIndex and not m.isPlaylistTransitionPending
                m.pendingStartIndex = originalIndex
                m.pendingStartPosition = 0
                m.isPlaylistTransitionPending = true
                m.playbackStatusSuppressed = true
                m.playbackStatusSettleTimer.control = "stop"
                m.playlistItems[originalIndex].resumePosition = 0
            end if
            m.currentVideoIndex = originalIndex
            m.selectedPlaylistIndex = m.currentVideoIndex
            updatePlaylistSelection()
            if m.pendingStartIndex = m.currentVideoIndex and LCase(m.videoPlayer.state) = "playing"
                applyResumePosition()
            end if
        end if
    end if
    reportPlaybackStatus()
end sub

sub handlePlaybackCommand(command as String, indexValue as String, positionValue as String)
    if not m.isPlaying
        showReceiverMessage("RECEPTOR ATIVO", "Nenhum vídeo está em reprodução para controlar.")
        return
    end if

    if command = "pause"
        m.videoPlayer.control = "pause"
    else if command = "play" or command = "resume"
        m.videoPlayer.control = "resume"
    else if command = "next"
        jumpByPlaylistOffset(1)
    else if command = "previous"
        jumpByPlaylistOffset(-1)
    else if command = "select"
        jumpToOriginalIndex(Int(Val(indexValue)))
    else if command = "forward"
        seekBySeconds(10)
    else if command = "rewind"
        seekBySeconds(-10)
    else if command = "seek"
        seekToPosition(Int(Val(positionValue)))
    end if
end sub

sub jumpToOriginalIndex(originalIndex as Integer)
    if originalIndex < 0 or originalIndex >= m.playlistItems.Count() then return
    if originalIndex = m.currentVideoIndex then return
    key = originalIndex.ToStr()
    if not m.originalToInternal.DoesExist(key) then return
    internalIndex = m.originalToInternal[key]
    if not m.isPlaylist
        if internalIndex = 0 and originalIndex = m.currentVideoIndex then return
        return
    end if

    beginPlaylistTransition(originalIndex, internalIndex)
end sub

sub beginPlaylistTransition(originalIndex as Integer, internalIndex as Integer)
    stopContinuousSeek()
    m.seekCommitTimer.control = "stop"
    m.seekTargetTimer.control = "stop"
    m.hasPendingSeek = false
    m.pendingStartIndex = originalIndex
    m.pendingStartPosition = 0
    m.isPlaylistTransitionPending = true
    m.playbackStatusSuppressed = true
    m.playbackStatusSettleTimer.control = "stop"
    m.resumeAppliedIndex = -1
    m.playlistItems[originalIndex].resumePosition = 0
    m.videoPlayer.nextContentIndex = internalIndex
    m.selectedPlaylistIndex = originalIndex
    updatePlaylistSelection()
    m.videoPlayer.control = "skipcontent"
end sub

sub jumpByPlaylistOffset(offset as Integer)
    if not m.isPlaylist or m.orderedOriginalIndexes.Count() < 2
        showPlaybackNotice("A PLAYLIST TEM APENAS UM VÍDEO")
        return
    end if
    selectedKey = m.selectedPlaylistIndex.ToStr()
    if m.originalToInternal.DoesExist(selectedKey)
        currentInternalIndex = m.originalToInternal[selectedKey]
    else
        currentInternalIndex = m.videoPlayer.contentIndex
    end if
    if currentInternalIndex = invalid then return
    targetInternalIndex = currentInternalIndex + offset
    if targetInternalIndex < 0
        showPlaybackNotice("ESTE É O PRIMEIRO VÍDEO")
        return
    end if
    if targetInternalIndex >= m.orderedOriginalIndexes.Count()
        showPlaybackNotice("ESTE É O ÚLTIMO VÍDEO")
        return
    end if
    originalIndex = m.orderedOriginalIndexes[targetInternalIndex]
    beginPlaylistTransition(originalIndex, targetInternalIndex)
end sub

sub seekBySeconds(offsetSeconds as Integer)
    currentPosition = m.videoPlayer.position
    if m.hasPendingSeek then currentPosition = m.pendingSeekPosition
    if currentPosition = invalid then currentPosition = 0
    targetPosition = currentPosition + offsetSeconds
    actionLabel = "+10 SEGUNDOS"
    if offsetSeconds < 0 then actionLabel = "-10 SEGUNDOS"
    queueSeekPosition(targetPosition, actionLabel, true)
end sub

sub seekToPosition(position as Integer)
    queueSeekPosition(position, "IR PARA POSIÇÃO", true)
end sub

sub queueSeekPosition(position as Dynamic, actionLabel as String, debounce as Boolean)
    if position = invalid then position = 0
    duration = m.videoPlayer.duration
    if position < 0 then position = 0
    if duration <> invalid and duration > 0 and position > duration then position = duration

    m.pendingSeekPosition = Int(position)
    m.hasPendingSeek = true
    m.seekTargetTimer.control = "stop"
    m.seekTargetTimer.control = "start"
    showPlaybackProgress(m.pendingSeekPosition, duration, actionLabel)
    m.seekCommitTimer.control = "stop"
    if debounce then
        m.seekCommitTimer.control = "start"
    else
        m.seekCommitTimer.control = "stop"
    end if
end sub

sub commitPendingSeek()
    if not m.hasPendingSeek then return
    m.videoPlayer.seek = m.pendingSeekPosition
    m.seekCommitTimer.control = "stop"
    m.seekTargetTimer.control = "stop"
    m.seekTargetTimer.control = "start"
end sub

sub clearPendingSeekTarget()
    m.hasPendingSeek = false
    m.seekTargetTimer.control = "stop"
end sub

sub startContinuousSeek(direction as Integer)
    if m.continuousSeekDirection = direction then return

    m.continuousSeekTimer.control = "stop"
    m.continuousSeekDirection = direction
    if m.hasPendingSeek
        m.continuousSeekTarget = m.pendingSeekPosition
    else
        m.continuousSeekTarget = m.videoPlayer.position
    end if
    if m.continuousSeekTarget = invalid then m.continuousSeekTarget = 0
    m.seekCommitTimer.control = "stop"
    applyContinuousSeekStep()
    m.continuousSeekTimer.control = "start"
end sub

sub onContinuousSeekTimer()
    if m.continuousSeekDirection <> 0 then applyContinuousSeekStep()
end sub

sub applyContinuousSeekStep()
    m.continuousSeekTarget = m.continuousSeekTarget + (10 * m.continuousSeekDirection)
    if m.continuousSeekTarget < 0 then m.continuousSeekTarget = 0
    duration = m.videoPlayer.duration
    if duration <> invalid and duration > 0 and m.continuousSeekTarget > duration
        m.continuousSeekTarget = duration
    end if

    actionLabel = "AVANÇANDO"
    if m.continuousSeekDirection < 0 then actionLabel = "VOLTANDO"
    queueSeekPosition(m.continuousSeekTarget, actionLabel, false)
end sub

sub stopContinuousSeek()
    wasSeeking = m.continuousSeekDirection <> 0
    m.continuousSeekDirection = 0
    m.continuousSeekTimer.control = "stop"
    if wasSeeking then commitPendingSeek()
end sub

sub showPlaybackProgress(position as Dynamic, duration as Dynamic, actionLabel as String)
    if position = invalid then position = 0
    if duration = invalid then duration = 0
    position = Int(position)
    duration = Int(duration)

    progressWidth = 0
    if duration > 0
        progressWidth = Int(1280 * position / duration)
        if progressWidth < 0 then progressWidth = 0
        if progressWidth > 1280 then progressWidth = 1280
    end if

    m.playbackNotice.visible = false
    m.progressActionLabel.text = actionLabel
    m.progressTimeLabel.text = formatPlaybackTime(position) + " / " + formatPlaybackTime(duration)
    m.progressBarFill.width = progressWidth
    m.progressOverlay.visible = true
    m.progressOverlayTimer.control = "stop"
    m.progressOverlayTimer.control = "start"
end sub

sub hidePlaybackProgress()
    m.progressOverlay.visible = false
end sub

sub onPlaybackStatusTimer()
    applyResumePosition()
    reportPlaybackStatus()
end sub

sub applyResumePosition()
    if LCase(m.videoPlayer.state) <> "playing" then return
    if m.currentVideoIndex < 0 or m.currentVideoIndex >= m.playlistItems.Count() then return

    if m.isPlaylistTransitionPending
        if m.currentVideoIndex <> m.pendingStartIndex then return
        startPosition = m.pendingStartPosition
        duration = m.videoPlayer.duration
        if duration <> invalid and duration > 0 and startPosition >= duration - 5 then startPosition = 0
        m.playlistItems[m.currentVideoIndex].resumePosition = startPosition
        m.videoPlayer.seek = startPosition
        m.resumeAppliedIndex = m.currentVideoIndex
        m.pendingStartIndex = -1
        m.isPlaylistTransitionPending = false
        m.playbackStatusSettleTimer.control = "stop"
        m.playbackStatusSettleTimer.control = "start"
        return
    end if
    if m.resumeAppliedIndex = m.currentVideoIndex then return

    resumePosition = m.playlistItems[m.currentVideoIndex].resumePosition
    if resumePosition = invalid then resumePosition = 0
    duration = m.videoPlayer.duration
    if duration <> invalid and duration > 0 and resumePosition >= duration - 5 then resumePosition = 0

    m.resumeAppliedIndex = m.currentVideoIndex
    m.videoPlayer.seek = resumePosition
end sub

sub reportPlaybackStatus()
    if m.playbackStatusUrl = "" then return
    if not m.isPlaying and not m.playbackStatusPending then return
    if m.isPlaylistTransitionPending then return
    if m.playbackStatusSuppressed then return
    if LCase(m.playbackStatusTask.state) = "run"
        m.playbackStatusPending = true
        return
    end if

    currentItemTitle = ""
    currentPosition = m.videoPlayer.position
    durationSeconds = m.videoPlayer.duration
    if currentPosition = invalid then currentPosition = 0
    if m.hasPendingSeek then currentPosition = m.pendingSeekPosition
    if durationSeconds = invalid then durationSeconds = 0
    if durationSeconds <= 0 then durationSeconds = 0

    playbackState = LCase(m.videoPlayer.state)
    if playbackState = "playing" or playbackState = "paused"
        audioFormat = m.videoPlayer.audioFormat
        if audioFormat <> invalid and audioFormat <> "" then m.playbackAudioFormat = LCase(audioFormat)
    end if

    if m.currentVideoIndex >= 0 and m.currentVideoIndex < m.playlistItems.Count()
        currentItemTitle = m.playlistItems[m.currentVideoIndex].title
        if durationSeconds = 0
            itemDuration = m.playlistItems[m.currentVideoIndex].durationSeconds
            if itemDuration <> invalid and itemDuration > 0 then durationSeconds = itemDuration
        end if
        if currentPosition <> invalid and currentPosition > 0
            m.playlistItems[m.currentVideoIndex].resumePosition = Int(currentPosition)
        end if
    end if

    payload = {
        index: m.currentVideoIndex,
        title: currentItemTitle,
        state: LCase(m.videoPlayer.state),
        positionSeconds: Int(currentPosition),
        durationSeconds: Int(durationSeconds),
        audioFormat: m.playbackAudioFormat,
        errorCode: m.playbackErrorCode,
        errorCategory: m.playbackErrorCategory,
        errorMessage: m.playbackErrorMessage,
        errorDetails: m.playbackErrorDetails
    }
    m.playbackStatusTask.url = m.playbackStatusUrl
    m.playbackStatusTask.payload = FormatJSON(payload)
    m.playbackStatusPending = false
    m.playbackStatusTask.control = "RUN"
end sub

sub onPlaybackStatusSettle()
    m.playbackStatusSuppressed = false
    reportPlaybackStatus()
end sub

sub onPlaybackStatusPosted(event as Object)
    taskNode = event.GetRoSGNode()
    if taskNode.result >= 200 and taskNode.result < 300 and m.playbackStatusPending
        reportPlaybackStatus()
    end if
end sub

sub togglePlaylistOverlay()
    if not m.isPlaying or m.playlistItems.Count() = 0 then return
    m.playlistOverlay.visible = not m.playlistOverlay.visible
    if m.playlistOverlay.visible
        m.playbackNotice.visible = false
        m.progressOverlay.visible = false
        m.progressOverlayTimer.control = "stop"
        m.selectedPlaylistIndex = m.currentVideoIndex
        updatePlaylistSelection()
        m.top.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

sub showPlaybackNotice(message as String)
    m.progressOverlay.visible = false
    m.progressOverlayTimer.control = "stop"
    m.playbackNoticeLabel.text = message
    m.playbackNotice.visible = true
end sub

sub updatePlaylistSelection()
    if m.playlistItems.Count() = 0 then return
    m.playlistOverlayTitle.text = "EPISÓDIOS · " + (m.selectedPlaylistIndex + 1).ToStr() + "/" + m.playlistItems.Count().ToStr()
    m.playlistOverlaySubtitle.text = "Use as setas para navegar e OK para iniciar o episódio selecionado."

    visibleRows = 9
    firstIndex = m.selectedPlaylistIndex - 4
    if firstIndex < 0 then firstIndex = 0
    maxFirstIndex = m.playlistItems.Count() - visibleRows
    if maxFirstIndex < 0 then maxFirstIndex = 0
    if firstIndex > maxFirstIndex then firstIndex = maxFirstIndex
    lastIndex = firstIndex + visibleRows - 1
    if lastIndex >= m.playlistItems.Count() then lastIndex = m.playlistItems.Count() - 1

    rowCount = lastIndex - firstIndex + 1
    for rowOffset = 0 to 8
        rowNodes = m.playlistRowNodes[rowOffset]
        if rowOffset >= rowCount
            rowNodes.group.visible = false
        else
            index = firstIndex + rowOffset
            rowNodes.group.visible = true
            rowNodes.background.color = "0x172638FF"
            if index = m.selectedPlaylistIndex then rowNodes.background.color = "0x234238FF"
            rowNodes.numberLabel.text = "EP " + padTimePart(index + 1)
            rowNodes.titleLabel.text = m.playlistItems[index].title
            if index = m.currentVideoIndex
                rowNodes.metadataLabel.text = "TOCANDO AGORA"
            else
                rowNodes.metadataLabel.text = "DISPONÍVEL"
            end if
            resumePosition = m.playlistItems[index].resumePosition
            if index <> m.currentVideoIndex and resumePosition <> invalid and resumePosition > 0
                rowNodes.metadataLabel.text = "RETOMAR EM " + formatPlaybackTime(resumePosition)
            end if
        end if
    end for
end sub

sub initializePlaylistRows()
    for rowOffset = 0 to 8
        row = m.playlistRows.createChild("Group")
        row.translation = [0, rowOffset * 74]
        row.visible = false

        rowBackground = row.createChild("Rectangle")
        rowBackground.width = 1140
        rowBackground.height = 68
        rowBackground.color = "0x172638FF"

        numberLabel = row.createChild("Label")
        numberLabel.translation = [18, 0]
        numberLabel.width = 72
        numberLabel.height = 68
        numberLabel.text = ""
        numberLabel.color = "0x55E1BEFF"
        numberLabel.font = m.playlistOverlayFooter.font
        numberLabel.vertAlign = "center"

        titleLabel = row.createChild("Label")
        titleLabel.translation = [105, 1]
        titleLabel.width = 1000
        titleLabel.height = 48
        titleLabel.text = ""
        titleLabel.color = "0xF3F7FFFF"
        titleLabel.font = m.playlistSelectionFont
        titleLabel.vertAlign = "center"
        titleLabel.wrap = true
        titleLabel.numLines = 2

        metadataLabel = row.createChild("Label")
        metadataLabel.translation = [105, 47]
        metadataLabel.width = 1000
        metadataLabel.height = 20
        metadataLabel.color = "0xAAB5C5FF"
        metadataLabel.font = m.playlistOverlayFooter.font
        metadataLabel.vertAlign = "center"

        m.playlistRowNodes.Push({
            group: row,
            background: rowBackground,
            numberLabel: numberLabel,
            titleLabel: titleLabel,
            metadataLabel: metadataLabel
        })
    end for
end sub

sub stopPlayback(message as String)
    stopContinuousSeek()
    m.pendingStartIndex = -1
    m.isPlaylistTransitionPending = false
    m.playbackStatusSuppressed = false
    m.seekTargetTimer.control = "stop"
    m.hasPendingSeek = false
    m.playbackStatusSettleTimer.control = "stop"
    reportPlaybackStatus()
    m.playbackStatusTimer.control = "stop"
    m.playlistOverlay.visible = false
    m.playbackNotice.visible = false
    m.progressOverlay.visible = false
    m.progressOverlayTimer.control = "stop"
    if LCase(m.playlistTask.state) = "run"
        m.currentPlaylistRequestId = m.currentPlaylistRequestId + 1
        m.playlistTask.control = "STOP"
    end if
    showReceiverMessage("RECEPTOR ATIVO", message)
end sub

sub showReceiverMessage(status as String, message as String)
    stopContinuousSeek()
    if m.isPlaying then m.videoPlayer.control = "stop"

    m.videoPlayer.visible = false
    m.canvas.visible = true
    m.isPlaying = false
    m.playbackStatusTimer.control = "stop"
    m.playlistOverlay.visible = false
    m.progressOverlay.visible = false
    m.progressOverlayTimer.control = "stop"
    m.statusLabel.text = status
    m.detailLabel.text = message
    m.top.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    normalizedKey = LCase(key)
    if not press
        if normalizedKey = "left" or normalizedKey = "right"
            stopContinuousSeek()
            return true
        end if
        return false
    end if

    if m.playlistOverlay.visible
        if normalizedKey = "up"
            if m.selectedPlaylistIndex > 0 then m.selectedPlaylistIndex = m.selectedPlaylistIndex - 1
            updatePlaylistSelection()
            return true
        else if normalizedKey = "down"
            if m.selectedPlaylistIndex < m.playlistItems.Count() - 1 then m.selectedPlaylistIndex = m.selectedPlaylistIndex + 1
            updatePlaylistSelection()
            return true
        else if normalizedKey = "ok" or normalizedKey = "select"
            selectedIndex = m.selectedPlaylistIndex
            m.playlistOverlay.visible = false
            m.top.setFocus(true)
            jumpToOriginalIndex(selectedIndex)
            return true
        else if normalizedKey = "back"
            m.playlistOverlay.visible = false
            m.top.setFocus(true)
            return true
        end if
    end if

    if (normalizedKey = "options" or normalizedKey = "info" or normalizedKey = "up" or normalizedKey = "down") and m.isPlaying
        togglePlaylistOverlay()
        return true
    end if

    if normalizedKey = "play" and m.isPlaying
        if LCase(m.videoPlayer.state) = "paused"
            m.videoPlayer.control = "resume"
        else
            m.videoPlayer.control = "pause"
        end if
        return true
    end if

    if (normalizedKey = "next" or normalizedKey = "channelup") and m.isPlaying
        jumpByPlaylistOffset(1)
        return true
    end if

    if (normalizedKey = "previous" or normalizedKey = "channeldown") and m.isPlaying
        jumpByPlaylistOffset(-1)
        return true
    end if

    if normalizedKey = "fwd" and m.isPlaying
        seekBySeconds(10)
        return true
    end if

    if normalizedKey = "rev" and m.isPlaying
        seekBySeconds(-10)
        return true
    end if

    if normalizedKey = "left" and m.isPlaying
        startContinuousSeek(-1)
        return true
    end if

    if normalizedKey = "replay" and m.isPlaying
        seekBySeconds(-10)
        return true
    end if

    if normalizedKey = "right" and m.isPlaying
        startContinuousSeek(1)
        return true
    end if

    if normalizedKey = "back" and m.isPlaying
        stopPlayback("Reprodução encerrada. A TV está pronta para receber outro.")
        return true
    end if

    return false
end function

function getParameter(parameters as Object, targetName as String) as String
    for each parameterName in parameters
        if LCase(parameterName) = LCase(targetName)
            value = parameters[parameterName]
            if value <> invalid then return value.ToStr()
        end if
    end for

    return ""
end function

function inferStreamFormat(videoUrl as String) as String
    queryPosition = Instr(1, videoUrl, "?")
    if queryPosition > 0 then videoPath = Left(videoUrl, queryPosition - 1) else videoPath = videoUrl
    videoPath = LCase(videoPath)

    if Right(videoPath, 5) = ".m3u8" then return "hls"
    if Right(videoPath, 4) = ".mp4" or Right(videoPath, 4) = ".m4v" then return "mp4"
    if Right(videoPath, 4) = ".mpd" then return "dash"
    if Instr(1, videoPath, ".ism/manifest") > 0 then return "ism"

    return "hls"
end function

function formatPlaybackTime(totalSeconds as Integer) as String
    if totalSeconds < 0 then totalSeconds = 0
    totalMinutes = Int(totalSeconds / 60)
    seconds = totalSeconds mod 60
    hours = Int(totalMinutes / 60)
    minutes = totalMinutes mod 60

    if hours > 0
        return hours.ToStr() + ":" + padTimePart(minutes) + ":" + padTimePart(seconds)
    end if
    return padTimePart(minutes) + ":" + padTimePart(seconds)
end function

function padTimePart(value as Integer) as String
    if value < 10 then return "0" + value.ToStr()
    return value.ToStr()
end function
