--[[
  fiche-recap.lua — construit la « fiche récapitulative » PDF (format typst) d'une fiche.
  Appliqué uniquement au format typst (voir fiches/_metadata.yml). La version HTML n'est pas touchée.

  Garde : l'encadré « À retenir », Question, Dispositif, le texte de « Résultats clés »
  (sans les graphiques interactifs), la figure principale (analyse/figure_principale.png)
  et Limites. Remplace « Ressources » par des liens absolus vers le site.
]]

local GARDER = {
  ["Question"] = true, ["Dispositif"] = true,
  ["Résultats clés"] = true, ["Limites"] = true,
}

local function fichier_existe(chemin)
  local f = io.open(chemin, "r")
  if f then f:close() return true end
  return false
end

local function a_classe(el, classe)
  return el.classes and el.classes:includes(classe)
end

-- Bloc à retirer dans la version papier (graphiques OJS, sorties de code, encadrés de liens)
local function a_retirer(b)
  if b.t == "CodeBlock" or b.t == "RawBlock" then return true end
  if b.t == "Div" and (a_classe(b, "cell") or a_classe(b, "callout-note")) then return true end
  -- encadré « Protocoles utilisés » (callout transformé par Quarto en nœud personnalisé)
  if b.t == "Div" and pandoc.utils.stringify(b):find("Protocoles utilisés", 1, true) then return true end
  if b.t == "Para" and #b.content == 0 then return true end
  return false
end

-- Rend absolus les liens relatifs, pour qu'ils marchent depuis le PDF téléchargé
local function liens_absolus(base_fiche, base_site)
  return {
    Link = function(l)
      local t = l.target
      if t:match("^%a[%w+.-]*:") or t:match("^#") then return l end
      if t:match("^%.%./%.%./") then
        l.target = base_site .. "/" .. t:gsub("^%.%./%.%./", ""):gsub("%.qmd$", ".html")
      else
        l.target = base_fiche .. "/" .. t:gsub("%.qmd$", ".html")
      end
      return l
    end
  }
end

function Pandoc(doc)
  -- Encadrés « note » (liens vers les protocoles) : inutiles sur papier
  doc = doc:walk({ Callout = function(c) if c.type == "note" then return {} end end })

  -- Auteurs : garder ceux de la fiche, sans l'auteur par défaut du dossier
  for _, cle in ipairs({"author", "authors", "by-author"}) do
    local a = doc.meta[cle]
    if a and pandoc.utils.type(a) == "List" and #a > 1 then
      local gardes = pandoc.List()
      for _, x in ipairs(a) do
        local nom = x
        if type(x) == "table" and x.name then nom = x.name.literal or x.name end
        if pandoc.utils.stringify(nom) ~= "PEPA Lab – UCLouvain" then gardes:insert(x) end
      end
      if #gardes > 0 then doc.meta[cle] = gardes end
    end
  end
  doc.meta["subtitle"] = pandoc.Inlines("Fiche récapitulative · Maraîchage · PEPA Lab (UCLouvain)")
  local base_site = doc.meta["recap-base-url"] and pandoc.utils.stringify(doc.meta["recap-base-url"]) or ""
  base_site = base_site:gsub("/$", "")
  local entree = quarto.doc.input_file or ""
  local slug = entree:match("fiches/([^/]+)/[^/]+$") or ""
  local base_fiche = base_site .. "/fiches/" .. slug
  local res = doc.meta["ressources"] or {}
  local function meta(cle) return res[cle] and pandoc.utils.stringify(res[cle]) or nil end

  local sortie = pandoc.List()
  local section = nil     -- nil = avant le premier titre de niveau 2
  local figure_ajoutee = false

  local function ajouter_figure()
    if figure_ajoutee then return end
    figure_ajoutee = true
    if fichier_existe("analyse/figure_principale.png") then
      sortie:insert(pandoc.Para({ pandoc.Image({}, "analyse/figure_principale.png", "", pandoc.Attr("", {}, {{"width", "100%"}})) }))
    end
  end

  for _, b in ipairs(doc.blocks) do
    if b.t == "Header" and b.level == 2 then
      if section == "Résultats clés" then ajouter_figure() end
      section = pandoc.utils.stringify(b.content)
      if GARDER[section] then sortie:insert(b) end
    elseif section == nil or GARDER[section] then
      if not a_retirer(b) then sortie:insert(b) end
    end
  end
  if section == "Résultats clés" then ajouter_figure() end

  -- Ressources : liste de liens absolus
  local items = pandoc.List()
  local function lien(texte, cle)
    local v = meta(cle)
    if v and v ~= "" and not v:match("XXXX") then
      local cible = v:match("^%a[%w+.-]*:") and v or nil
      if not cible then
        cible = v:match("^%.%./%.%./") and (base_site .. "/" .. v:gsub("^%.%./%.%./", "")) or (base_fiche .. "/" .. v)
      end
      items:insert({ pandoc.Plain({ pandoc.Strong(texte .. " : "), pandoc.Link(cible, cible) }) })
    end
  end
  items:insert(1, { pandoc.Plain({ pandoc.Strong("Fiche en ligne (graphiques interactifs) : "), pandoc.Link(base_fiche .. "/", base_fiche .. "/") }) })
  lien("Document complet", "memoire")
  lien("Données", "donnees")
  lien("Données brutes archivées", "doi")
  lien("Scripts d'analyse", "code")
  sortie:insert(pandoc.Header(2, "Pour aller plus loin"))
  sortie:insert(pandoc.BulletList(items))

  local auteurs = doc.meta["auteurs"] and pandoc.utils.stringify(doc.meta["auteurs"]) or ""
  local annee = doc.meta["annee"] and pandoc.utils.stringify(doc.meta["annee"]) or ""
  local titre = doc.meta["title"] and pandoc.utils.stringify(doc.meta["title"]) or ""
  sortie:insert(pandoc.Para({ pandoc.Strong("Citer cette fiche : "),
    pandoc.Str(auteurs .. " (" .. annee .. "). "), pandoc.Emph(titre),
    pandoc.Str(". Fiche PEPA Lab, UCLouvain. Licence CC BY 4.0.") }))

  doc.blocks = pandoc.Blocks(sortie):walk(liens_absolus(base_fiche, base_site))
  return doc
end
