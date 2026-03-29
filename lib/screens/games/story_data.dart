class StoryData {
  static const List<Map<String, dynamic>> stories = [
    {
      'id': 'orman_macerasi',
      'nodes': {
        'start': {
          'text': 'Karanlık bir ormanda uyandın. Gözlerini açtığında etrafında hiçbir şey göremiyorsun. Sadece uzaktan gelen bir su sesi duyuyorsun. Ne yaparsın?',
          'choices': [
            {'text': 'Su sesine doğru yürü', 'next': 'river'},
            {'text': 'Olduğun yerde bekle ve dinle', 'next': 'wait'},
          ]
        },
        'river': {
          'text': 'Su sesini takip ederek geniş bir nehrin kenarına ulaştın. Nehrin karşısında eski bir kulübe görünüyor. Ayrıca nehrin kenarında küçük bir kayık var.',
          'choices': [
            {'text': 'Kayığa binip karşıya geç', 'next': 'cabin'},
            {'text': 'Nehir boyunca yürümeye devam et', 'next': 'walk_river'},
          ]
        },
        'wait': {
          'text': 'Bir süre olduğun yerde bekledin. Ay ışığı yavaş yavaş etrafı aydınlatmaya başladı. Yakınlarda bir patika belirdi.',
          'choices': [
            {'text': 'Patikayı takip et', 'next': 'path'},
            {'text': 'Geri dönüp uyumaya çalış', 'next': 'sleep'},
          ]
        },
        'cabin': {
          'text': 'Kayıkla zor da olsa karşıya geçtin. Kulübenin kapısı aralık. İçeriden loş bir ışık sızıyor.',
          'choices': [
            {'text': 'Kapıyı çal', 'next': 'knock'},
            {'text': 'Sessizce içeri gir', 'next': 'sneak'},
          ]
        },
        'walk_river': {
          'text': 'Nehir boyunca saatlerce yürüdün ve sonunda bir köye ulaştın. Güvendesin!\n\nSON.',
          'choices': [
            {'text': 'Tekrar Oyna', 'next': 'start'}
          ]
        },
        'path': {
          'text': 'Patika seni büyük bir mağaraya götürdü. Mağaranın içinde parlayan taşlar var.',
          'choices': [
            {'text': 'Taşları incele', 'next': 'stones'},
            {'text': 'Mağaradan çık', 'next': 'leave_cave'},
          ]
        },
        'sleep': {
          'text': 'Gözlerini kapattın ve uykuya daldın. Sabah olduğunda kurtarma ekipleri seni buldu. Güvendesin!\n\nSON.',
          'choices': [
            {'text': 'Tekrar Oyna', 'next': 'start'}
          ]
        },
        'knock': {
          'text': 'Kapıyı çaldın. Yaşlı bir adam kapıyı açtı ve seni içeri davet etti. Sana sıcak çorba ikram etti. Güvendesin!\n\nSON.',
          'choices': [
            {'text': 'Tekrar Oyna', 'next': 'start'}
          ]
        },
        'sneak': {
          'text': 'Sessizce içeri girdin ama içerideki köpek seni fark edip havlamaya başladı! Yaşlı adam korkuyla uyanıp seni dışarı attı. Ormanda tekrar kayboldun.\n\nSON.',
          'choices': [
            {'text': 'Tekrar Oyna', 'next': 'start'}
          ]
        },
        'stones': {
          'text': 'Taşlar büyülüydü! Onlara dokunur dokunmaz kendini evinde buldun. Büyülü bir macera yaşadın.\n\nSON.',
          'choices': [
            {'text': 'Tekrar Oyna', 'next': 'start'}
          ]
        },
        'leave_cave': {
          'text': 'Mağaradan çıktın ve ormanda kayboldun. Belki de taşları incelemeliydin.\n\nSON.',
          'choices': [
            {'text': 'Tekrar Oyna', 'next': 'start'}
          ]
        }
      }
    }
  ];
}
