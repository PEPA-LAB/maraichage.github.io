--[[
  statut-fiche.lua — ajoute en tête de chaque fiche un encadré qui indique le niveau
  de confiance des résultats, selon le champ « statut » de l'en-tête :
    Préliminaire (par défaut) · Consolidé · Publié
  Appliqué à la page web et à la fiche récapitulative PDF (voir fiches/_metadata.yml).
]]

local TEXTES = {
  ["Préliminaire"] = {
    type = "warning",
    titre = "Résultats préliminaires",
    texte = "Ces résultats viennent d'un travail de fin d'études, en général sur une seule saison et un seul site, sans relecture par des pairs. Ils donnent des pistes à confirmer, pas des recommandations établies."
  },
  ["Consolidé"] = {
    type = "note",
    titre = "Résultats consolidés",
    texte = "Ces résultats ont été confirmés sur plusieurs saisons ou plusieurs sites, mais n'ont pas encore été publiés dans une revue scientifique."
  },
  ["Publié"] = {
    type = "tip",
    titre = "Résultats publiés",
    texte = "Ces résultats ont été publiés dans une revue scientifique, après relecture par des pairs."
  },
}

function Pandoc(doc)
  local statut = doc.meta["statut"] and pandoc.utils.stringify(doc.meta["statut"]) or "Préliminaire"
  local t = TEXTES[statut] or TEXTES["Préliminaire"]
  local contenu = pandoc.Blocks({ pandoc.Para(pandoc.Inlines(t.texte)) })
  if statut == "Publié" and doc.meta["publication"] then
    local url = pandoc.utils.stringify(doc.meta["publication"])
    contenu = pandoc.Blocks({ pandoc.Para({ pandoc.Str(t.texte .. " "), pandoc.Link("Lire l'article", url) }) })
  end
  local encadre = quarto.Callout({
    type = t.type, title = t.titre, content = contenu,
    appearance = "simple", icon = false
  })
  doc.blocks:insert(1, encadre)
  return doc
end
