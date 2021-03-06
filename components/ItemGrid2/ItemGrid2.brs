sub init()

  m.options = m.top.findNode("options")

  m.itemGrid = m.top.findNode("itemGrid")
  m.backdrop = m.top.findNode("backdrop")
  m.newBackdrop = m.top.findNode("backdropTransition")
  m.emptyText = m.top.findNode("emptyText")

  m.swapAnimation = m.top.findNode("backroundSwapAnimation")
  m.swapAnimation.observeField("state", "swapDone")

  m.loadedRows = 0
  m.loadedItems = 0

  m.data = CreateObject("roSGNode", "ContentNode")

  m.itemGrid.content = m.data
  m.itemGrid.setFocus(true)

  m.itemGrid.observeField("itemFocused", "onItemFocused")
  m.itemGrid.observeField("itemSelected", "onItemSelected")
  m.newBackdrop.observeField("loadStatus", "newBGLoaded")

  'Background Image Queued for loading
  m.queuedBGUri = ""

  'Item sort - maybe load defaults from user prefs?
  m.sortField = "SortName"
  m.sortAscending = true

  m.loadItemsTask = createObject("roSGNode", "LoadItemsTask2")
  m.loadItemsTask.observeField("content", "ItemDataLoaded")

end sub

'
'Load initial set of Data
sub loadInitialItems()

  if m.top.parentItem.backdropUrl <> invalid then
    SetBackground(m.top.parentItem.backdropUrl)
  end if

  m.loadItemsTask.itemId = m.top.parentItem.Id
  m.loadItemsTask.sortField = m.sortField
  m.loadItemsTask.sortAscending = m.sortAscending
  m.loadItemsTask.startIndex = 0

  if m.top.parentItem.collectionType = "movies" then
    m.loadItemsTask.itemType = "Movie"
  else if m.top.parentItem.collectionType = "tvshows" then
    m.loadItemsTask.itemType = "Series"
  end if

  m.loadItemsTask.control = "RUN"

  SetUpOptions()

end sub

' Data to display when options button selected
sub SetUpOptions()

  options = {}

  'Movies
  if m.top.parentItem.collectionType = "movies" then
    options.views = [{ "Title": tr("Movies"), "Name": "movies" }]
    options.sort = [
      { "Title": tr("TITLE"), "Name": "SortName" },
      { "Title": tr("IMDB_RATING"), "Name": "CommunityRating" },
      { "Title": tr("CRITIC_RATING"), "Name": "CriticRating" },
      { "Title": tr("DATE_ADDED"), "Name": "DateCreated" },
      { "Title": tr("DATE_PLAYED"), "Name": "DatePlayed" },
      { "Title": tr("OFFICIAL_RATING"), "Name": "OfficialRating" },
      { "Title": tr("PLAY_COUNT"), "Name": "PlayCount" },
      { "Title": tr("RELEASE_DATE"), "Name": "PremiereDate" },
      { "Title": tr("RUNTIME"), "Name": "Runtime" }
    ]
  'TV Shows
  else if m.top.parentItem.collectionType = "tvshows" then
    options.views = [{ "Title": tr("Shows"), "Name": "shows" }]
    options.sort = [
      { "Title": tr("TITLE"), "Name": "SortName" },
      { "Title": tr("IMDB_RATING"), "Name": "CommunityRating" },
      { "Title": tr("DATE_ADDED"), "Name": "DateCreated" },
      { "Title": tr("DATE_PLAYED"), "Name": "DatePlayed" },
      { "Title": tr("OFFICIAL_RATING"), "Name": "OfficialRating" },
      { "Title": tr("RELEASE_DATE"), "Name": "PremiereDate" },
    ]

  end if

  for each o in options.sort
    if o.Name = m.sortField then
      o.Selected = true
      o.Ascending = m.sortAscending
    end if
  end for

  m.options.options = options

end sub


'
'Handle loaded data, and add to Grid
sub ItemDataLoaded(msg)

  itemData = msg.GetData()
  data = msg.getField()

  if itemData = invalid then
    m.Loading = false
    return
  end if

  for each item in itemData
    m.data.appendChild(item)
  end for

  'Update the stored counts
  m.loadedItems = m.itemGrid.content.getChildCount()
  m.loadedRows = m.loadedItems / m.itemGrid.numColumns
  m.Loading = false

  'If there are no items to display, show message
  if m.loadedItems = 0 then
    m.emptyText.text = tr("NO_ITEMS").Replace("%1", m.top.parentItem.Type)
    m.emptyText.visible = true
  end if

  m.itemGrid.setFocus(true)

end sub

'
'Set Background Image
sub SetBackground(backgroundUri as string)

  'If a new image is being loaded, or transitioned to, store URL to load next
  if m.swapAnimation.state <> "stopped" or m.newBackdrop.loadStatus = "loading" then
    m.queuedBGUri = backgroundUri
    return
  end if

  m.newBackdrop.uri = backgroundUri
end sub

'
'Handle new item being focused
sub onItemFocused()

  focusedRow = CInt(m.itemGrid.itemFocused / m.itemGrid.numColumns) + 1

  itemInt = m.itemGrid.itemFocused

  ' If no selected item, set background to parent backdrop
  if itemInt = -1 then
    return
  end if

  ' Set Background to item backdrop
  SetBackground(m.itemGrid.content.getChild(m.itemGrid.itemFocused).backdropUrl)

  ' Load more data if focus is within last 3 rows, and there are more items to load
  if focusedRow >= m.loadedRows - 3 and m.loadeditems < m.loadItemsTask.totalRecordCount then
    loadMoreData()
  end if
end sub

'
'When Image Loading Status changes
sub newBGLoaded()
  'If image load was sucessful, start the fade swap
  if m.newBackdrop.loadStatus = "ready"
    m.swapAnimation.control = "start"
  end if
end sub

'
'Swap Complete
sub swapDone()

  if m.swapAnimation.state = "stopped" then

    'Set main BG node image and hide transitioning node
    m.backdrop.uri = m.newBackdrop.uri
    m.backdrop.opacity = 0.25
    m.newBackdrop.opacity = 0

    'If there is another one to load
    if m.newBackdrop.uri <> m.queuedBGUri and m.queuedBGUri <> "" then
      SetBackground(m.queuedBGUri)
      m.queuedBGUri = ""
    end if
  end if
end sub

'
'Load next set of items
sub loadMoreData()

  if m.Loading = true then return

  m.Loading = true
  m.loadItemsTask.startIndex = m.loadedItems
  m.loadItemsTask.control = "RUN"
end sub

'
'Item Selected
sub onItemSelected()
  m.top.selectedItem = m.itemGrid.content.getChild(m.itemGrid.itemSelected)
end sub


'
'Check if options updated and any reloading required
sub optionsClosed()
  if m.options.sortField <> m.sortField or m.options.sortAscending <> m.sortAscending then
    m.sortField = m.options.sortField
    m.sortAscending = m.options.sortAscending
    m.loadedRows = 0
    m.loadedItems = 0
    m.data = CreateObject("roSGNode", "ContentNode")
    m.itemGrid.content = m.data
    loadInitialItems()
  end if
  m.itemGrid.setFocus(true)
end sub


function onKeyEvent(key as string, press as boolean) as boolean

  if not press then return false

  if key = "options"
    if m.options.visible = true then
      m.options.visible = false
      optionsClosed()
    else
      m.options.visible = true
      m.options.setFocus(true)
    end if
    return true
  else if key = "back" then
    if m.options.visible = true then
      m.options.visible = false
      optionsClosed()
      return true
    end if
  end if
  return false
end function
