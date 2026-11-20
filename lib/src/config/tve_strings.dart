/// Tous les textes de l'interface. Français par défaut ; surchargez ce que vous voulez :
/// `TveStrings(live: 'Live', radio: 'Radio FM')`.
class TveStrings {
  final String live, radio, replay, shorts, news, schedule, podcasts, about;
  final String search, searchHint, noResults, empty, retry, loading, errorTitle, networkError;
  final String share, privacyPolicy, contact, followUs, version, developedBy;
  final String onAir, upNext, today, playbackUnavailable, playlists, allVideos, readMore;
  final String watchOnYoutube, youtubeNotEmbeddable, youtubeError;

  const TveStrings({
    this.live = 'Direct',
    this.radio = 'Radio',
    this.replay = 'Replay',
    this.shorts = 'Shorts',
    this.news = 'Actualités',
    this.schedule = 'Programmes',
    this.podcasts = 'Podcasts',
    this.about = 'À propos',
    this.search = 'Rechercher',
    this.searchHint = 'Émissions, vidéos, actualités…',
    this.noResults = 'Aucun résultat',
    this.empty = 'Rien pour le moment',
    this.retry = 'Réessayer',
    this.loading = 'Chargement…',
    this.errorTitle = 'Une erreur est survenue',
    this.networkError = 'Vérifiez votre connexion internet.',
    this.share = 'Partager',
    this.privacyPolicy = 'Politique de confidentialité',
    this.contact = 'Contact',
    this.followUs = 'Suivez-nous',
    this.version = 'Version',
    this.developedBy = 'Développé par',
    this.onAir = 'En ce moment',
    this.upNext = 'À suivre',
    this.today = "Aujourd'hui",
    this.playbackUnavailable = 'Le direct est momentanément indisponible.',
    this.playlists = 'Playlists',
    this.allVideos = 'Toutes les vidéos',
    this.readMore = 'Lire la suite',
    this.watchOnYoutube = 'Regarder sur YouTube',
    this.youtubeNotEmbeddable = 'Cette vidéo ne peut être lue que sur YouTube.',
    this.youtubeError = "Lecture impossible dans l'application.",
  });
}
