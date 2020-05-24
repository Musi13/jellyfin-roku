function ItemsList(params = {} as object)
  ' Gets items based on a query.
  resp = APIRequest("Items", params)
  data = getJson(resp)
  ' TODO - parse items
  return data
end function

function UserItems(params = {} as object)
  ' Gets items based on a query
  resp = APIRequest(Substitute("Items/{0}/Items", get_setting("active_user")), params)
  data = getJson(resp)
  ' TODO - parse items
  return data
end function

function UserItemsResume(params = {} as object)
  ' Gets items based on a query
  resp = APIRequest(Substitute("Items/{0}/Items/Resume", get_setting("active_user")), params)
  data = getJson(resp)
  ' TODO - parse items
  return data
end function

function ItemGetPlaybackInfo(id as string, StartTimeTicks = 0 as longinteger)
  params = {
    "UserId": get_setting("active_user"),
    "StartTimeTicks": StartTimeTicks,
    "IsPlayback": true,
    "AutoOpenLiveStream": true,
    "MaxStreamingBitrate": "140000000"
  }
  resp = APIRequest(Substitute("Items/{0}/PlaybackInfo", id), params)
  return getJson(resp)
end function

function ItemPostPlaybackInfo(id as string, StartTimeTicks = 0 as longinteger)
  'This profile is kind of a guess based on Roku's docs and a profile I
  'took from jellyfin-web/firefox. Also it has to be less than 2048 bytes once
  'encoded as json, or you have to figure out multipart upload.
  'But it seems to work for my use case
  body = {
    "DeviceProfile": {
      "MaxStreamingBitrate": 120000000,
      "MaxStaticBitrate": 100000000,
      "MusicStreamingTranscodingBitrate": 192000,
      "DirectPlayProfiles": [
        {
          "Container": "mp4,m4v",
          "Type": "Video",
          "VideoCodec": "h264,vp8,vp9",
          "AudioCodec": "aac,opus,flac,vorbis"
        },
        {
          "Container": "mp3",
          "Type": "Audio",
          "AudioCodec": "mp3"
        },
        {
          "Container": "aac",
          "Type": "Audio"
        },
        {
          "Container": "m4a",
          "AudioCodec": "aac",
          "Type": "Audio"
        },
        {
          "Container": "flac",
          "Type": "Audio"
        }
      ],
      "TranscodingProfiles": [
        {
          "Container": "aac",
          "Type": "Audio",
          "AudioCodec": "aac",
          "Context": "Streaming",
          "Protocol": "http",
          "MaxAudioChannels": "2"
        },
        {
          "Container": "mp3",
          "Type": "Audio",
          "AudioCodec": "mp3",
          "Context": "Streaming",
          "Protocol": "http",
          "MaxAudioChannels": "2"
        },
        {
          "Container": "mp3",
          "Type": "Audio",
          "AudioCodec": "mp3",
          "Context": "Static",
          "Protocol": "http",
          "MaxAudioChannels": "2"
        },
        {
          "Container": "aac",
          "Type": "Audio",
          "AudioCodec": "aac",
          "Context": "Static",
          "Protocol": "http",
          "MaxAudioChannels": "2"
        },
        {
          "Container": "ts",
          "Type": "Video",
          "AudioCodec": "aac",
          "VideoCodec": "h264",
          "Context": "Streaming",
          "Protocol": "hls",
          "MaxAudioChannels": "2",
          "MinSegments": "1",
          "BreakOnNonKeyFrames": true
        },
        {
          "Container": "mp4",
          "Type": "Video",
          "AudioCodec": "aac,opus,flac,vorbis",
          "VideoCodec": "h264",
          "Context": "Static",
          "Protocol": "http"
        }
      ],
      "ContainerProfiles": [],
      "CodecProfiles": [
        {
          "Type": "VideoAudio",
          "Codec": "aac",
          "Conditions": [
            {
              "Condition": "Equals",
              "Property": "IsSecondaryAudio",
              "Value": "false",
              "IsRequired": false
            }
          ]
        },
        {
          "Type": "Video",
          "Codec": "h264",
          "Conditions": [
            {
              "Condition": "EqualsAny",
              "Property": "VideoProfile",
              "Value": "high|main|baseline|constrained baseline",
              "IsRequired": false
            },
            {
              "Condition": "LessThanEqual",
              "Property": "VideoLevel",
              "Value": "51",
              "IsRequired": false
            }
          ]
        }
      ],
      "SubtitleProfiles": [
        {
          "Format": "vtt",
          "Method": "External"
        },
        {
          "Format": "ass",
          "Method": "External"
        },
        {
          "Format": "ssa",
          "Method": "External"
        }
      ],
      "ResponseProfiles": [
        {
          "Type": "Video",
          "Container": "m4v",
          "MimeType": "video/mp4"
        }
      ]
    }
  }
  params = {
    "UserId": get_setting("active_user"),
    "StartTimeTicks": StartTimeTicks,
    "IsPlayback": true,
    "AutoOpenLiveStream": true,
    "MaxStreamingBitrate": "140000000"
  }
  req = APIRequest(Substitute("Items/{0}/PlaybackInfo", id), params)
  req.SetRequest("POST")
  return postJson(req, FormatJson(body))
end function

' Search across all libraries
function SearchMedia(query as string)
  ' This appears to be done differently on the web now
  ' For each potential type, a separate query is done:
  ' varying item types, and artists, and people
  resp = APIRequest(Substitute("Users/{0}/Items", get_setting("active_user")), {
    "searchTerm": query,
    "IncludePeople": true,
    "IncludeMedia": true,
    "IncludeGenres": false,
    "IncludeStudios": false,
    "IncludeArtists": false,
    ' "IncludeItemTypes: "Movie",
    "EnableTotalRecordCount": false,
    "ImageTypeLimit": 1,
    "Recursive": true
  })
  data = getJson(resp)
  results = []
  for each item in data.Items
    tmp = CreateObject("roSGNode", "SearchData")
    tmp.image = PosterImage(item.id)
    tmp.json = item
    results.push(tmp)
  end for
  data.SearchHints = results
  return data
end function

' List items from within a library
function ItemList(library_id = invalid as string, params = {})
  if params["limit"] = invalid
    params["limit"] = 30
  end if
  if params["page"] = invalid
    params["page"] = 1
  end if
  params["parentid"] = library_id
  params["recursive"] = true

  url = Substitute("Users/{0}/Items/", get_setting("active_user"))
  resp = APIRequest(url, params)
  data = getJson(resp)
  results = []
  for each item in data.Items
    imgParams = {}
    if item.ImageTags.Primary <> invalid then
      ' If Primary image exists use it
      param = { "Tag" : item.ImageTags.Primary }
      imgParams.Append(param)
    end if
    param = { "AddPlayedIndicator": item.UserData.Played }
    imgParams.Append(param)
    if item.UserData.PlayedPercentage <> invalid then
      param = { "PercentPlayed": item.UserData.PlayedPercentage }
      imgParams.Append(param)
    end if
    if item.type = "Movie"
      tmp = CreateObject("roSGNode", "MovieData")
      tmp.image = PosterImage(item.id, imgParams)
      tmp.json = item
      results.push(tmp)
    else if item.type = "Series"
      if item.UserData.UnplayedItemCount > 0 then
        param = { "UnplayedCount" : item.UserData.UnplayedItemCount }
        imgParams.Append(param)
      end if
      tmp = CreateObject("roSGNode", "SeriesData")
      tmp.image = PosterImage(item.id, imgParams)
      tmp.json = item
      results.push(tmp)
    else if item.type = "BoxSet"
      if item.UserData.UnplayedItemCount > 0 then
        param = { "UnplayedCount" : item.UserData.UnplayedItemCount }
        imgParams.Append(param)
      end if
      tmp = CreateObject("roSGNode", "CollectionData")
      tmp.image = PosterImage(item.id, imgParams)
      tmp.json = item
      results.push(tmp)
    else
      print "Items.brs::ItemList received unhandled type: " item.type
      ' Otherwise we just stick with the JSON
      results.push(item)
    end if
  end for
  data.items = results
  return data
end function

' MetaData about an item
function ItemMetaData(id as string)
  url = Substitute("Users/{0}/Items/{1}", get_setting("active_user"), id)
  resp = APIRequest(url)
  data = getJson(resp)
  imgParams = {}
  if data.UserData.PlayedPercentage <> invalid then
    param = { "PercentPlayed": data.UserData.PlayedPercentage }
    imgParams.Append(param)
  end if
  if data.type = "Movie"
    tmp = CreateObject("roSGNode", "MovieData")
    tmp.image = PosterImage(data.id, imgParams)
    tmp.json = data
    return tmp
  else if data.type = "Series"
    tmp = CreateObject("roSGNode", "SeriesData")
    tmp.image = PosterImage(data.id)
    tmp.json = data
    return tmp
  else if data.type = "Episode"
    ' param = { "AddPlayedIndicator": data.UserData.Played }
    ' imgParams.Append(param)
    tmp = CreateObject("roSGNode", "TVEpisodeData")
    tmp.image = PosterImage(data.id, imgParams)
    tmp.json = data
    return tmp
  else if data.type = "BoxSet"
    tmp = CreateObject("roSGNode", "CollectionData")
    tmp.image = PosterImage(data.id, imgParams)
    tmp.json = item
    return tmp
  else if data.type = "Season"
    tmp = CreateObject("roSGNode", "TVSeasonData")
    tmp.image = PosterImage(data.id)
    tmp.json = data
    return tmp
  else if data.type = "TvChannel"
    tmp = CreateObject("roSGNode", "ChannelData")
    tmp.image = PosterImage(data.id)
    tmp.json = data
    return tmp
  else
    print "Items.brs::ItemMetaData processed unhandled type: " data.type
    ' Return json if we don't know what it is
    return data
  end if
  return data
end function

' Seasons for a TV Show
function TVSeasons(id as string)
  url = Substitute("Shows/{0}/Seasons", id)
  resp = APIRequest(url, { "UserId": get_setting("active_user") })

  data = getJson(resp)
  results = []
  for each item in data.Items
    imgParams = { "AddPlayedIndicator": item.UserData.Played }
    if item.UserData.UnplayedItemCount > 0 then
      param = { "UnplayedCount" : item.UserData.UnplayedItemCount }
      imgParams.Append(param)
    end if
    tmp = CreateObject("roSGNode", "TVEpisodeData")
    tmp.image = PosterImage(item.id, imgParams)
    tmp.json = item
    results.push(tmp)
  end for
  data.Items = results
  return data
end function

function TVEpisodes(show_id as string, season_id as string)
  url = Substitute("Shows/{0}/Episodes", show_id)
  resp = APIRequest(url, { "seasonId": season_id, "UserId": get_setting("active_user") })

  data = getJson(resp)
  results = []
  for each item in data.Items
    imgParams = { "AddPlayedIndicator": item.UserData.Played, "maxWidth": 712, "maxheight": 400 }
    if item.UserData.PlayedPercentage <> invalid then
      param = { "PercentPlayed": item.UserData.PlayedPercentage }
      imgParams.Append(param)
    end if
    tmp = CreateObject("roSGNode", "TVEpisodeData")
    tmp.image = PosterImage(item.id, imgParams)
    if tmp.image <> invalid
      tmp.image.posterDisplayMode = "scaleToFit"
    end if
    tmp.json = item
    tmp.overview = ItemMetaData(item.id).overview
    results.push(tmp)
  end for
  data.Items = results
  return data
end function

' The next up episode for a TV show
function TVNext(id as string)
  url = Substitute("Shows/NextUp", id)
  resp = APIRequest(url, { "UserId": get_setting("active_user"), "SeriesId": id })

  data = getJson(resp)
  for each item in data.Items
    item.image = PosterImage(item.id)
  end for
  return data
end function

function Channels()
  resp = APIRequest("LiveTv/Channels", {})

  data = getJson(resp)
  results = []
  for each item in data.Items
    imgParams = { "maxWidth": 712, "maxheight": 400 }
    tmp = CreateObject("roSGNode", "ChannelData")
    tmp.image = PosterImage(item.id, imgParams)
    if tmp.image <> invalid
      tmp.image.posterDisplayMode = "scaleToFit"
    end if
    tmp.json = item
    results.push(tmp)
  end for
  data.Items = results
  return data
end function
