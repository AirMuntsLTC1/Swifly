// suggest_data.dart - built-in suggestion lists for the profile editor.
//
// One entry per line: `Title|Subtitle` (the subtitle is optional).
// Keep each list ordered from most to least popular: when two entries match a
// search equally well, the one listed first is shown first.
//
// These lists work offline. Real, user-created values (for example a small
// company nobody listed here) come from DatabaseService.searchSuggestions, and
// anything typed by hand can always be saved as a custom entry.

const String kCompaniesRaw = r'''
Google|Technology
Microsoft|Technology
Apple|Technology
Amazon|E-commerce and cloud
Meta|Social media
Tesla|Automotive and energy
Netflix|Streaming
Samsung Electronics|Electronics
Intel|Semiconductors
IBM|Technology
Oracle|Software
Adobe|Software
Salesforce|Software
Nvidia|Semiconductors
AMD|Semiconductors
Spotify|Music streaming
Uber|Transportation
Airbnb|Travel
Twitter|Social media
X Corp|Social media
LinkedIn|Social media
TikTok|Social media
ByteDance|Technology
Snapchat|Social media
Pinterest|Social media
Reddit|Social media
Discord|Communication
Telegram|Messaging
WhatsApp|Messaging
Zoom|Communication
Slack|Communication
Dropbox|Cloud storage
Shopify|E-commerce
PayPal|Payments
Stripe|Payments
Square|Payments
Visa|Payments
Mastercard|Payments
Flutterwave|Payments
Paystack|Payments
Opay|Fintech
Moniepoint|Fintech
Kuda Bank|Fintech
M-Pesa|Mobile money
Safaricom|Telecommunications
MTN Group|Telecommunications
Airtel|Telecommunications
Vodafone|Telecommunications
Orange|Telecommunications
Globacom|Telecommunications
Jumia|E-commerce
Konga|E-commerce
Andela|Technology
Interswitch|Fintech
Dangote Group|Conglomerate
Access Bank|Banking
Zenith Bank|Banking
GTBank|Banking
First Bank of Nigeria|Banking
UBA|Banking
Ecobank|Banking
Standard Bank|Banking
Absa|Banking
Nedbank|Banking
Equity Bank|Banking
KCB Bank|Banking
Naspers|Technology and media
Shoprite|Retail
Woolworths|Retail
Pick n Pay|Retail
Sasol|Energy
Shell|Energy
BP|Energy
ExxonMobil|Energy
Chevron|Energy
TotalEnergies|Energy
Saudi Aramco|Energy
NNPC|Energy
Eni|Energy
Walmart|Retail
Target|Retail
Costco|Retail
Home Depot|Retail
IKEA|Retail
Alibaba|E-commerce
Tencent|Technology
Huawei|Technology
Xiaomi|Electronics
Oppo|Electronics
Vivo|Electronics
Tecno|Electronics
Infinix|Electronics
Sony|Electronics
LG|Electronics
Panasonic|Electronics
Toshiba|Electronics
Dell|Technology
HP|Technology
Lenovo|Technology
Asus|Technology
Acer|Technology
Cisco|Networking
Qualcomm|Semiconductors
Broadcom|Semiconductors
TSMC|Semiconductors
ARM|Semiconductors
SAP|Software
ServiceNow|Software
Workday|Software
Atlassian|Software
GitHub|Software
GitLab|Software
Figma|Software
Canva|Software
Notion|Software
Zendesk|Software
HubSpot|Software
Twilio|Software
Cloudflare|Software
Datadog|Software
Snowflake|Data
Palantir|Data
Databricks|Data
OpenAI|Artificial intelligence
Anthropic|Artificial intelligence
DeepMind|Artificial intelligence
Hugging Face|Artificial intelligence
Supabase|Software
Firebase|Software
DigitalOcean|Cloud
Vercel|Cloud
Heroku|Cloud
Accenture|Consulting
Deloitte|Consulting
PwC|Consulting
EY|Consulting
KPMG|Consulting
McKinsey & Company|Consulting
Boston Consulting Group|Consulting
Bain & Company|Consulting
Capgemini|Consulting
Infosys|IT services
Tata Consultancy Services|IT services
Wipro|IT services
Cognizant|IT services
HCL Technologies|IT services
Reliance Industries|Conglomerate
Tata Group|Conglomerate
Flipkart|E-commerce
Paytm|Fintech
Zomato|Food delivery
Swiggy|Food delivery
Grab|Transportation
Gojek|Transportation
Bolt|Transportation
Lyft|Transportation
DoorDash|Food delivery
Uber Eats|Food delivery
Glovo|Food delivery
Deliveroo|Food delivery
Booking.com|Travel
Expedia|Travel
Emirates|Airline
Qatar Airways|Airline
Ethiopian Airlines|Airline
Kenya Airways|Airline
Air Peace|Airline
British Airways|Airline
Lufthansa|Airline
Air France|Airline
Delta Air Lines|Airline
American Airlines|Airline
United Airlines|Airline
Turkish Airlines|Airline
Boeing|Aerospace
Airbus|Aerospace
SpaceX|Aerospace
NASA|Space agency
Lockheed Martin|Defense
Toyota|Automotive
Honda|Automotive
Nissan|Automotive
Ford|Automotive
General Motors|Automotive
Volkswagen|Automotive
BMW|Automotive
Mercedes-Benz|Automotive
Audi|Automotive
Hyundai|Automotive
Kia|Automotive
Rivian|Automotive
BYD|Automotive
Coca-Cola|Beverages
PepsiCo|Beverages
Nestle|Food
Unilever|Consumer goods
Procter & Gamble|Consumer goods
Johnson & Johnson|Healthcare
Pfizer|Pharmaceuticals
Moderna|Pharmaceuticals
Novartis|Pharmaceuticals
Roche|Pharmaceuticals
AstraZeneca|Pharmaceuticals
GlaxoSmithKline|Pharmaceuticals
Bayer|Pharmaceuticals
Nike|Apparel
Adidas|Apparel
Puma|Apparel
Zara|Apparel
H&M|Apparel
Gucci|Fashion
Louis Vuitton|Fashion
Chanel|Fashion
Prada|Fashion
Rolex|Luxury
Disney|Entertainment
Warner Bros.|Entertainment
Universal Pictures|Entertainment
Paramount|Entertainment
Sony Pictures|Entertainment
HBO|Entertainment
Amazon Prime Video|Streaming
YouTube|Video platform
Twitch|Streaming
Roblox|Gaming
Epic Games|Gaming
Electronic Arts|Gaming
Activision Blizzard|Gaming
Ubisoft|Gaming
Nintendo|Gaming
Valve|Gaming
Riot Games|Gaming
Supercell|Gaming
Tencent Games|Gaming
Rockstar Games|Gaming
Take-Two Interactive|Gaming
Goldman Sachs|Finance
JPMorgan Chase|Finance
Morgan Stanley|Finance
Citigroup|Finance
Bank of America|Banking
Wells Fargo|Banking
HSBC|Banking
Barclays|Banking
Standard Chartered|Banking
Deutsche Bank|Banking
BNP Paribas|Banking
UBS|Banking
Credit Suisse|Banking
BlackRock|Finance
Vanguard|Finance
Fidelity Investments|Finance
Charles Schwab|Finance
Robinhood|Fintech
Coinbase|Crypto
Binance|Crypto
Revolut|Fintech
Wise|Fintech
Monzo|Fintech
Chipper Cash|Fintech
Palmpay|Fintech
Piggyvest|Fintech
Cowrywise|Fintech
Bamboo|Fintech
Carbon|Fintech
Sterling Bank|Banking
Fidelity Bank|Banking
Wema Bank|Banking
Union Bank|Banking
Stanbic IBTC|Banking
Heritage Bank|Banking
Polaris Bank|Banking
FCMB|Banking
MultiChoice|Media
DStv|Media
Showmax|Streaming
Canal+|Media
BBC|Media
CNN|Media
Reuters|Media
Bloomberg|Media
The New York Times|Media
The Guardian|Media
Al Jazeera|Media
Channels Television|Media
Arise News|Media
Red Cross|Non-profit
United Nations|Government
UNICEF|Non-profit
World Health Organization|Government
World Bank|Government
International Monetary Fund|Government
World Food Programme|Non-profit
Doctors Without Borders|Non-profit
Bill & Melinda Gates Foundation|Non-profit
Google.org|Non-profit
Peace Corps|Government
Federal Government|Government
State Government|Government
Local Government|Government
Police Force|Government
Army|Military
Navy|Military
Air Force|Military
Self-employed|Self-employed
Freelancer|Self-employed
Entrepreneur|Self-employed
Own business|Self-employed
Student|Education
Unemployed|Not working
Starbucks|Food and drink
McDonald's|Food and drink
KFC|Food and drink
Burger King|Food and drink
Subway|Food and drink
Domino's|Food and drink
Pizza Hut|Food and drink
Chicken Republic|Food and drink
Mr Biggs|Food and drink
Hilton|Hospitality
Marriott|Hospitality
Hyatt|Hospitality
Radisson|Hospitality
Accor|Hospitality
FedEx|Logistics
UPS|Logistics
DHL|Logistics
Maersk|Logistics
Kobo360|Logistics
Gig Logistics|Logistics
Sendbox|Logistics
''';

const String kSchoolsRaw = r'''
Harvard University|Cambridge, USA
Stanford University|Stanford, USA
Massachusetts Institute of Technology|Cambridge, USA
Yale University|New Haven, USA
Princeton University|Princeton, USA
Columbia University|New York, USA
University of Pennsylvania|Philadelphia, USA
Cornell University|Ithaca, USA
Duke University|Durham, USA
Northwestern University|Evanston, USA
Brown University|Providence, USA
Dartmouth College|Hanover, USA
California Institute of Technology|Pasadena, USA
Johns Hopkins University|Baltimore, USA
University of Chicago|Chicago, USA
New York University|New York, USA
Carnegie Mellon University|Pittsburgh, USA
Georgia Institute of Technology|Atlanta, USA
University of California, Berkeley|Berkeley, USA
University of California, Los Angeles|Los Angeles, USA
University of Michigan|Ann Arbor, USA
University of Texas at Austin|Austin, USA
University of Washington|Seattle, USA
University of Florida|Gainesville, USA
Ohio State University|Columbus, USA
Arizona State University|Tempe, USA
Boston University|Boston, USA
Purdue University|West Lafayette, USA
Howard University|Washington, USA
Morehouse College|Atlanta, USA
University of Oxford|Oxford, UK
University of Cambridge|Cambridge, UK
Imperial College London|London, UK
University College London|London, UK
King's College London|London, UK
London School of Economics|London, UK
University of Edinburgh|Edinburgh, UK
University of Manchester|Manchester, UK
University of Warwick|Coventry, UK
University of Bristol|Bristol, UK
University of Leeds|Leeds, UK
University of Birmingham|Birmingham, UK
University of Glasgow|Glasgow, UK
University of Toronto|Toronto, Canada
McGill University|Montreal, Canada
University of British Columbia|Vancouver, Canada
University of Waterloo|Waterloo, Canada
University of Alberta|Edmonton, Canada
York University|Toronto, Canada
University of Melbourne|Melbourne, Australia
University of Sydney|Sydney, Australia
Australian National University|Canberra, Australia
Monash University|Melbourne, Australia
University of Auckland|Auckland, New Zealand
ETH Zurich|Zurich, Switzerland
Technical University of Munich|Munich, Germany
Humboldt University of Berlin|Berlin, Germany
Heidelberg University|Heidelberg, Germany
Sorbonne University|Paris, France
Sciences Po|Paris, France
University of Amsterdam|Amsterdam, Netherlands
Delft University of Technology|Delft, Netherlands
KU Leuven|Leuven, Belgium
Karolinska Institute|Stockholm, Sweden
University of Copenhagen|Copenhagen, Denmark
University of Oslo|Oslo, Norway
University of Helsinki|Helsinki, Finland
Bocconi University|Milan, Italy
University of Barcelona|Barcelona, Spain
University of Lisbon|Lisbon, Portugal
Peking University|Beijing, China
Tsinghua University|Beijing, China
Fudan University|Shanghai, China
Zhejiang University|Hangzhou, China
University of Hong Kong|Hong Kong
National University of Singapore|Singapore
Nanyang Technological University|Singapore
University of Tokyo|Tokyo, Japan
Kyoto University|Kyoto, Japan
Seoul National University|Seoul, South Korea
KAIST|Daejeon, South Korea
Indian Institute of Technology Bombay|Mumbai, India
Indian Institute of Technology Delhi|New Delhi, India
Indian Institute of Science|Bengaluru, India
University of Delhi|New Delhi, India
American University of Beirut|Beirut, Lebanon
King Saud University|Riyadh, Saudi Arabia
Cairo University|Cairo, Egypt
American University in Cairo|Cairo, Egypt
University of Cape Town|Cape Town, South Africa
University of the Witwatersrand|Johannesburg, South Africa
Stellenbosch University|Stellenbosch, South Africa
University of Pretoria|Pretoria, South Africa
University of Johannesburg|Johannesburg, South Africa
University of Nairobi|Nairobi, Kenya
Strathmore University|Nairobi, Kenya
Kenyatta University|Nairobi, Kenya
Makerere University|Kampala, Uganda
University of Dar es Salaam|Dar es Salaam, Tanzania
Addis Ababa University|Addis Ababa, Ethiopia
University of Ghana|Accra, Ghana
Kwame Nkrumah University of Science and Technology|Kumasi, Ghana
University of Cape Coast|Cape Coast, Ghana
Ashesi University|Berekuso, Ghana
University of Rwanda|Kigali, Rwanda
University of Lagos|Lagos, Nigeria
University of Ibadan|Ibadan, Nigeria
Obafemi Awolowo University|Ile-Ife, Nigeria
University of Nigeria, Nsukka|Nsukka, Nigeria
Ahmadu Bello University|Zaria, Nigeria
University of Benin|Benin City, Nigeria
University of Ilorin|Ilorin, Nigeria
University of Port Harcourt|Port Harcourt, Nigeria
Lagos State University|Lagos, Nigeria
Covenant University|Ota, Nigeria
Babcock University|Ilishan-Remo, Nigeria
Federal University of Technology, Akure|Akure, Nigeria
Federal University of Technology, Minna|Minna, Nigeria
Federal University of Technology, Owerri|Owerri, Nigeria
Nnamdi Azikiwe University|Awka, Nigeria
University of Uyo|Uyo, Nigeria
University of Calabar|Calabar, Nigeria
University of Abuja|Abuja, Nigeria
University of Jos|Jos, Nigeria
Bayero University Kano|Kano, Nigeria
Delta State University|Abraka, Nigeria
Ambrose Alli University|Ekpoma, Nigeria
Rivers State University|Port Harcourt, Nigeria
Ladoke Akintola University of Technology|Ogbomoso, Nigeria
Federal University Oye-Ekiti|Oye-Ekiti, Nigeria
Pan-Atlantic University|Lagos, Nigeria
Lead City University|Ibadan, Nigeria
Landmark University|Omu-Aran, Nigeria
Afe Babalola University|Ado-Ekiti, Nigeria
American University of Nigeria|Yola, Nigeria
Nile University of Nigeria|Abuja, Nigeria
Bells University of Technology|Ota, Nigeria
Redeemer's University|Ede, Nigeria
Yaba College of Technology|Lagos, Nigeria
Federal Polytechnic, Ilaro|Ilaro, Nigeria
The Polytechnic, Ibadan|Ibadan, Nigeria
Kaduna Polytechnic|Kaduna, Nigeria
Federal College of Education|Nigeria
University of Sao Paulo|Sao Paulo, Brazil
University of Buenos Aires|Buenos Aires, Argentina
National Autonomous University of Mexico|Mexico City, Mexico
Pontifical Catholic University of Chile|Santiago, Chile
University of the Andes|Bogota, Colombia
University of the West Indies|Kingston, Jamaica
Lagos Business School|Lagos, Nigeria
INSEAD|Fontainebleau, France
London Business School|London, UK
Harvard Business School|Boston, USA
Stanford Graduate School of Business|Stanford, USA
Wharton School|Philadelphia, USA
Kellogg School of Management|Evanston, USA
MIT Sloan School of Management|Cambridge, USA
Community College|College
High School|School
Senior Secondary School|School
Junior Secondary School|School
Government College|School
Federal Government College|School
Command Secondary School|School
International School|School
Grammar School|School
Boarding School|School
Primary School|School
Home schooled|School
Self-taught|Education
Bootcamp|Education
Coursera|Online learning
Udemy|Online learning
edX|Online learning
Khan Academy|Online learning
freeCodeCamp|Online learning
ALX Africa|Online learning
Moringa School|Coding school
Decagon Institute|Coding school
Altschool Africa|Coding school
Harvard Extension School|Online learning
''';

const String kJobTitlesRaw = r'''
Software Engineer
Frontend Developer
Backend Developer
Full-Stack Developer
Mobile App Developer
Flutter Developer
Android Developer
iOS Developer
DevOps Engineer
Data Scientist
Data Analyst
Data Engineer
Machine Learning Engineer
AI Researcher
Cybersecurity Analyst
Cloud Architect
Systems Administrator
Network Engineer
QA Engineer
Game Developer
UI/UX Designer
Product Designer
Graphic Designer
Motion Designer
Video Editor
Photographer
Videographer
Content Creator
Social Media Manager
Digital Marketer
Marketing Manager
Brand Strategist
Copywriter
Journalist
Editor
Writer
Product Manager
Project Manager
Program Manager
Business Analyst
Operations Manager
Customer Success Manager
Customer Support Specialist
Sales Representative
Account Executive
Business Development Manager
Recruiter
HR Manager
Accountant
Financial Analyst
Investment Banker
Auditor
Tax Consultant
Entrepreneur
Founder
Co-founder
CEO
CTO
COO
CFO
Director
Consultant
Lawyer
Paralegal
Doctor
Surgeon
Nurse
Pharmacist
Dentist
Physiotherapist
Medical Laboratory Scientist
Teacher
Lecturer
Professor
Researcher
Tutor
Civil Engineer
Mechanical Engineer
Electrical Engineer
Chemical Engineer
Petroleum Engineer
Architect
Surveyor
Interior Designer
Fashion Designer
Tailor
Makeup Artist
Hair Stylist
Chef
Barista
Waiter
Hotel Manager
Pilot
Flight Attendant
Driver
Logistics Coordinator
Supply Chain Manager
Farmer
Mechanic
Electrician
Plumber
Carpenter
Security Officer
Police Officer
Soldier
Musician
Producer
DJ
Actor
Dancer
Comedian
Athlete
Coach
Personal Trainer
Pastor
Imam
Social Worker
Volunteer
Intern
Freelancer
''';

const String kFieldsOfStudyRaw = r'''
Computer Science
Software Engineering
Information Technology
Data Science
Artificial Intelligence
Cybersecurity
Electrical Engineering
Electronic Engineering
Mechanical Engineering
Civil Engineering
Chemical Engineering
Petroleum Engineering
Biomedical Engineering
Medicine and Surgery
Nursing
Pharmacy
Dentistry
Public Health
Biology
Biochemistry
Microbiology
Chemistry
Physics
Mathematics
Statistics
Economics
Accounting
Finance
Business Administration
Marketing
Law
Political Science
International Relations
Psychology
Sociology
Mass Communication
Journalism
English Language
Linguistics
History
Philosophy
Theology
Education
Architecture
Fine Arts
Graphic Design
Music
Theatre Arts
Film Studies
Agriculture
Environmental Science
Geology
Biotechnology
Veterinary Medicine
Hospitality Management
Urban Planning
''';

const String kHobbiesRaw = r'''
Reading|Indoor
Writing|Creative
Gaming|Indoor
Coding|Tech
Music|Creative
Singing|Creative
Dancing|Creative
Drawing|Creative
Painting|Creative
Photography|Creative
Videography|Creative
Video editing|Creative
Graphic design|Creative
Cooking|Food
Baking|Food
Travelling|Outdoor
Hiking|Outdoor
Camping|Outdoor
Fishing|Outdoor
Gardening|Outdoor
Cycling|Sport
Running|Sport
Swimming|Sport
Football|Sport
Basketball|Sport
Table tennis|Sport
Tennis|Sport
Volleyball|Sport
Gym and fitness|Sport
Yoga|Wellness
Meditation|Wellness
Chess|Games
Ludo|Games
Draughts|Games
Board games|Games
Puzzles|Games
Card games|Games
Watching movies|Entertainment
Watching anime|Entertainment
Watching TV shows|Entertainment
Listening to music|Entertainment
Podcasts|Entertainment
Stand-up comedy|Entertainment
Blogging|Creative
Vlogging|Creative
Content creation|Creative
Learning languages|Learning
Public speaking|Learning
Debating|Learning
Volunteering|Community
Church activities|Community
Mentoring|Community
Fashion|Style
Thrifting|Style
Makeup|Style
Hair styling|Style
Collecting sneakers|Collecting
Collecting coins|Collecting
Collecting cards|Collecting
Electronics tinkering|Tech
Robotics|Tech
3D printing|Tech
Ethical hacking|Tech
Trading|Finance
Investing|Finance
Entrepreneurship|Business
Woodworking|Crafts
Knitting|Crafts
Sewing|Crafts
Pottery|Crafts
Calligraphy|Crafts
Origami|Crafts
Bird watching|Outdoor
Stargazing|Outdoor
Surfing|Outdoor
Skateboarding|Sport
Boxing|Sport
Martial arts|Sport
Karate|Sport
Taekwondo|Sport
Wrestling|Sport
Athletics|Sport
Golf|Sport
Cricket|Sport
Rugby|Sport
Badminton|Sport
Horse riding|Outdoor
Playing guitar|Music
Playing piano|Music
Playing drums|Music
Playing bass|Music
Producing beats|Music
DJing|Music
Rapping|Music
Songwriting|Music
Karaoke|Music
Road trips|Outdoor
Beach days|Outdoor
Food tasting|Food
Coffee|Food
Tea|Food
Home decor|Lifestyle
Pets|Lifestyle
Dog walking|Lifestyle
Astronomy|Science
Science experiments|Science
History|Learning
Philosophy|Learning
Quizzes and trivia|Games
Esports|Games
Mobile gaming|Games
Streaming|Entertainment
Netflix and chill|Entertainment
Sleeping|Lifestyle
Shopping|Lifestyle
Scrapbooking|Crafts
Journaling|Creative
Poetry|Creative
Storytelling|Creative
Acting|Creative
Modelling|Style
''';

const String kMusicRaw = r'''
Burna Boy|Artist
Wizkid|Artist
Davido|Artist
Tems|Artist
Rema|Artist
Asake|Artist
Ayra Starr|Artist
CKay|Artist
Fireboy DML|Artist
Omah Lay|Artist
Tiwa Savage|Artist
Olamide|Artist
Tyla|Artist
Black Sherif|Artist
Sarkodie|Artist
Stonebwoy|Artist
Diamond Platnumz|Artist
Sauti Sol|Artist
Fela Kuti|Artist
Taylor Swift|Artist
Beyonce|Artist
Rihanna|Artist
Drake|Artist
Kendrick Lamar|Artist
Kanye West|Artist
Jay-Z|Artist
J. Cole|Artist
Travis Scott|Artist
Eminem|Artist
Nicki Minaj|Artist
Cardi B|Artist
Lil Wayne|Artist
Post Malone|Artist
The Weeknd|Artist
Bruno Mars|Artist
Ed Sheeran|Artist
Adele|Artist
Dua Lipa|Artist
Ariana Grande|Artist
Billie Eilish|Artist
Olivia Rodrigo|Artist
Justin Bieber|Artist
Selena Gomez|Artist
Lady Gaga|Artist
Katy Perry|Artist
Harry Styles|Artist
Doja Cat|Artist
SZA|Artist
Lizzo|Artist
Coldplay|Artist
Imagine Dragons|Artist
Maroon 5|Artist
Linkin Park|Artist
Queen|Artist
The Beatles|Artist
Michael Jackson|Artist
Bob Marley|Artist
Whitney Houston|Artist
Prince|Artist
Stevie Wonder|Artist
Alicia Keys|Artist
Usher|Artist
Chris Brown|Artist
BTS|Artist
BLACKPINK|Artist
Stray Kids|Artist
NewJeans|Artist
Bad Bunny|Artist
Shakira|Artist
J Balvin|Artist
Karol G|Artist
Peso Pluma|Artist
Daddy Yankee|Artist
David Guetta|Artist
Calvin Harris|Artist
Avicii|Artist
Martin Garrix|Artist
Marshmello|Artist
Alan Walker|Artist
Hillsong Worship|Artist
Bethel Music|Artist
Elevation Worship|Artist
Nathaniel Bassey|Artist
Sinach|Artist
Don Moen|Artist
Afrobeats|Genre
Afropop|Genre
Amapiano|Genre
Afro fusion|Genre
Highlife|Genre
Juju|Genre
Fuji|Genre
Gqom|Genre
Bongo Flava|Genre
Hip hop|Genre
Rap|Genre
Drill|Genre
Trap|Genre
R&B|Genre
Pop|Genre
Rock|Genre
Alternative|Genre
Indie|Genre
Metal|Genre
Punk|Genre
Jazz|Genre
Blues|Genre
Soul|Genre
Gospel|Genre
Worship|Genre
Reggae|Genre
Dancehall|Genre
Reggaeton|Genre
Latin|Genre
Country|Genre
Folk|Genre
Classical|Genre
Electronic|Genre
House|Genre
Techno|Genre
EDM|Genre
Lo-fi|Genre
K-pop|Genre
J-pop|Genre
Instrumental|Genre
Soundtracks|Genre
''';

const String kTvRaw = r'''
Breaking Bad|Drama
Game of Thrones|Fantasy
Stranger Things|Sci-fi
The Last of Us|Drama
Money Heist|Thriller
Squid Game|Thriller
Wednesday|Fantasy
The Witcher|Fantasy
House of the Dragon|Fantasy
The Boys|Superhero
Peaky Blinders|Crime
Better Call Saul|Drama
Narcos|Crime
Ozark|Crime
Prison Break|Crime
La Casa de Papel|Thriller
Dark|Sci-fi
Black Mirror|Sci-fi
The Crown|Drama
Bridgerton|Romance
Emily in Paris|Comedy
Sex Education|Comedy
Euphoria|Drama
Succession|Drama
The Bear|Drama
Ted Lasso|Comedy
Friends|Comedy
The Office|Comedy
Brooklyn Nine-Nine|Comedy
Parks and Recreation|Comedy
How I Met Your Mother|Comedy
The Big Bang Theory|Comedy
Modern Family|Comedy
Seinfeld|Comedy
Fresh Prince of Bel-Air|Comedy
Everybody Hates Chris|Comedy
Family Guy|Animation
The Simpsons|Animation
South Park|Animation
Rick and Morty|Animation
Bob's Burgers|Animation
Avatar: The Last Airbender|Animation
Attack on Titan|Anime
Naruto|Anime
One Piece|Anime
Dragon Ball Z|Anime
Death Note|Anime
Demon Slayer|Anime
Jujutsu Kaisen|Anime
My Hero Academia|Anime
Bleach|Anime
Fullmetal Alchemist|Anime
Hunter x Hunter|Anime
Tokyo Ghoul|Anime
Spy x Family|Anime
Chainsaw Man|Anime
One-Punch Man|Anime
Sword Art Online|Anime
Grey's Anatomy|Medical drama
House|Medical drama
The Good Doctor|Medical drama
Suits|Legal drama
How to Get Away with Murder|Legal drama
Criminal Minds|Crime
Law & Order|Crime
CSI|Crime
NCIS|Crime
Sherlock|Crime
True Detective|Crime
The Walking Dead|Horror
Supernatural|Fantasy
The Vampire Diaries|Fantasy
Riverdale|Drama
Gossip Girl|Drama
Pretty Little Liars|Drama
Vikings|Historical
The Last Kingdom|Historical
Downton Abbey|Historical
Chernobyl|Drama
Loki|Superhero
WandaVision|Superhero
The Mandalorian|Sci-fi
Andor|Sci-fi
Star Trek|Sci-fi
Doctor Who|Sci-fi
The Flash|Superhero
Arrow|Superhero
Gotham|Superhero
Lucifer|Fantasy
You|Thriller
Mindhunter|Crime
Sacred Games|Thriller
Mirzapur|Crime
Jenifa's Diary|Comedy
Blood Sisters|Drama
Shanty Town|Crime
Far From Home|Drama
Big Brother Naija|Reality
Nigerian Idol|Reality
The Voice|Reality
America's Got Talent|Reality
Love Island|Reality
Survivor|Reality
Selling Sunset|Reality
Keeping Up with the Kardashians|Reality
Gen V|Superhero
Reacher|Action
Lupin|Thriller
Cobra Kai|Drama
Heartstopper|Romance
Normal People|Romance
The Summer I Turned Pretty|Romance
Outer Banks|Drama
Shadow and Bone|Fantasy
Arcane|Animation
''';

const String kMoviesRaw = r'''
Avengers: Endgame|Superhero
Avengers: Infinity War|Superhero
Black Panther|Superhero
Spider-Man: No Way Home|Superhero
Iron Man|Superhero
Thor: Ragnarok|Superhero
Guardians of the Galaxy|Superhero
Deadpool|Superhero
The Dark Knight|Superhero
Batman Begins|Superhero
Joker|Drama
Wonder Woman|Superhero
Aquaman|Superhero
Avatar|Sci-fi
Avatar: The Way of Water|Sci-fi
Titanic|Romance
Inception|Sci-fi
Interstellar|Sci-fi
The Matrix|Sci-fi
Blade Runner 2049|Sci-fi
Dune|Sci-fi
Star Wars|Sci-fi
Jurassic Park|Adventure
Jurassic World|Adventure
The Lord of the Rings|Fantasy
The Hobbit|Fantasy
Harry Potter|Fantasy
Pirates of the Caribbean|Adventure
Indiana Jones|Adventure
Mad Max: Fury Road|Action
John Wick|Action
Mission: Impossible|Action
Fast & Furious|Action
Die Hard|Action
Top Gun: Maverick|Action
Gladiator|Action
Rambo|Action
Extraction|Action
The Equalizer|Action
Taken|Action
Kung Fu Panda|Animation
Frozen|Animation
The Lion King|Animation
Toy Story|Animation
Finding Nemo|Animation
Moana|Animation
Coco|Animation
Encanto|Animation
Spider-Man: Into the Spider-Verse|Animation
Shrek|Animation
Minions|Animation
Despicable Me|Animation
Barbie|Comedy
Oppenheimer|Drama
The Godfather|Crime
Pulp Fiction|Crime
Goodfellas|Crime
Scarface|Crime
Heat|Crime
The Shawshank Redemption|Drama
Forrest Gump|Drama
Fight Club|Drama
Parasite|Thriller
Se7en|Thriller
The Silence of the Lambs|Thriller
Shutter Island|Thriller
Get Out|Horror
Us|Horror
A Quiet Place|Horror
The Conjuring|Horror
It|Horror
Hereditary|Horror
Scream|Horror
The Notebook|Romance
La La Land|Romance
Crazy Rich Asians|Romance
Love and Basketball|Romance
Coming to America|Comedy
Home Alone|Comedy
Superbad|Comedy
The Hangover|Comedy
Step Brothers|Comedy
Mean Girls|Comedy
Big Daddy|Comedy
Wedding Party|Nollywood
King of Boys|Nollywood
Lionheart|Nollywood
Living in Bondage|Nollywood
Omo Ghetto: The Saga|Nollywood
Anikulapo|Nollywood
Brotherhood|Nollywood
Jagun Jagun|Nollywood
The Black Book|Nollywood
Gangs of Lagos|Nollywood
Citation|Nollywood
Seven Pounds|Drama
The Pursuit of Happyness|Drama
Hidden Figures|Drama
12 Years a Slave|Drama
Selma|Drama
RRR|Indian cinema
Baahubali|Indian cinema
3 Idiots|Indian cinema
Dangal|Indian cinema
Pathaan|Indian cinema
Spirited Away|Anime film
Your Name|Anime film
Demon Slayer: Mugen Train|Anime film
Dragon Ball Super: Broly|Anime film
''';

const String kGamesRaw = r'''
Call of Duty|Shooter
Call of Duty: Mobile|Mobile
Free Fire|Mobile
PUBG Mobile|Mobile
Fortnite|Battle royale
Minecraft|Sandbox
Roblox|Sandbox
GTA V|Action
Grand Theft Auto: San Andreas|Action
Red Dead Redemption 2|Action
FIFA|Sports
EA Sports FC|Sports
eFootball|Sports
PES|Sports
NBA 2K|Sports
Madden NFL|Sports
Mortal Kombat|Fighting
Tekken|Fighting
Street Fighter|Fighting
Super Smash Bros.|Fighting
Among Us|Party
Fall Guys|Party
Mario Kart|Racing
Need for Speed|Racing
Forza Horizon|Racing
Gran Turismo|Racing
Asphalt|Racing
Candy Crush|Puzzle
Subway Surfers|Mobile
Temple Run|Mobile
Clash of Clans|Mobile
Clash Royale|Mobile
Brawl Stars|Mobile
Mobile Legends|Mobile
Genshin Impact|RPG
Honkai: Star Rail|RPG
League of Legends|MOBA
Dota 2|MOBA
Valorant|Shooter
Counter-Strike 2|Shooter
Apex Legends|Battle royale
Overwatch 2|Shooter
Rainbow Six Siege|Shooter
Halo|Shooter
Battlefield|Shooter
Warzone|Battle royale
Elden Ring|RPG
Dark Souls|RPG
The Witcher 3|RPG
Skyrim|RPG
Cyberpunk 2077|RPG
Baldur's Gate 3|RPG
Final Fantasy|RPG
Pokemon|RPG
The Legend of Zelda|Adventure
Super Mario|Platformer
Sonic the Hedgehog|Platformer
God of War|Action
The Last of Us|Action
Spider-Man|Action
Assassin's Creed|Action
Hitman|Action
Resident Evil|Horror
Five Nights at Freddy's|Horror
Dead by Daylight|Horror
Hollow Knight|Indie
Celeste|Indie
Stardew Valley|Simulation
The Sims|Simulation
Animal Crossing|Simulation
Cities: Skylines|Simulation
Euro Truck Simulator|Simulation
Farming Simulator|Simulation
Rocket League|Sports
Chess.com|Board
Ludo King|Board
Monopoly|Board
Scrabble|Board
Uno|Card
Solitaire|Card
Poker|Card
Whot|Card
Draughts|Board
Tetris|Puzzle
Wordle|Puzzle
Pac-Man|Arcade
Space Invaders|Arcade
Dream League Soccer|Mobile
Hay Day|Mobile
Plants vs. Zombies|Strategy
Age of Empires|Strategy
Civilization|Strategy
StarCraft|Strategy
Warcraft|Strategy
World of Warcraft|MMO
Old School RuneScape|MMO
Destiny 2|Shooter
Diablo|RPG
Sea of Thieves|Adventure
It Takes Two|Co-op
Terraria|Sandbox
Don't Starve|Survival
Rust|Survival
ARK: Survival Evolved|Survival
''';

const String kSportsRaw = r'''
Real Madrid|Football club
FC Barcelona|Football club
Manchester United|Football club
Manchester City|Football club
Liverpool|Football club
Arsenal|Football club
Chelsea|Football club
Tottenham Hotspur|Football club
Newcastle United|Football club
Aston Villa|Football club
West Ham United|Football club
Everton|Football club
Leicester City|Football club
Bayern Munich|Football club
Borussia Dortmund|Football club
Paris Saint-Germain|Football club
Juventus|Football club
AC Milan|Football club
Inter Milan|Football club
Napoli|Football club
AS Roma|Football club
Atletico Madrid|Football club
Ajax|Football club
Benfica|Football club
Porto|Football club
Galatasaray|Football club
Al Nassr|Football club
Al Hilal|Football club
Inter Miami|Football club
LA Galaxy|Football club
Boca Juniors|Football club
River Plate|Football club
Flamengo|Football club
Santos|Football club
Kaizer Chiefs|Football club
Orlando Pirates|Football club
Mamelodi Sundowns|Football club
Al Ahly|Football club
Zamalek|Football club
Enyimba|Football club
Rangers International|Football club
Kano Pillars|Football club
Remo Stars|Football club
Shooting Stars|Football club
Plateau United|Football club
Rivers United|Football club
Nigeria national football team|National team
Super Eagles|National team
Brazil national football team|National team
Argentina national football team|National team
France national football team|National team
England national football team|National team
Germany national football team|National team
Spain national football team|National team
Portugal national football team|National team
Ghana Black Stars|National team
Senegal national football team|National team
Morocco national football team|National team
Cameroon Indomitable Lions|National team
Ivory Coast Elephants|National team
Lionel Messi|Football player
Cristiano Ronaldo|Football player
Neymar Jr|Football player
Kylian Mbappe|Football player
Erling Haaland|Football player
Mohamed Salah|Football player
Kevin De Bruyne|Football player
Vinicius Junior|Football player
Jude Bellingham|Football player
Harry Kane|Football player
Bukayo Saka|Football player
Victor Osimhen|Football player
Ademola Lookman|Football player
Wilfred Ndidi|Football player
Alex Iwobi|Football player
Samuel Chukwueze|Football player
Kelechi Iheanacho|Football player
Jay-Jay Okocha|Football player
Nwankwo Kanu|Football player
Sadio Mane|Football player
Didier Drogba|Football player
Samuel Eto'o|Football player
Thierry Henry|Football player
Zinedine Zidane|Football player
Ronaldinho|Football player
Diego Maradona|Football player
Pele|Football player
LeBron James|Basketball player
Stephen Curry|Basketball player
Kevin Durant|Basketball player
Giannis Antetokounmpo|Basketball player
Kobe Bryant|Basketball player
Michael Jordan|Basketball player
Shaquille O'Neal|Basketball player
Joel Embiid|Basketball player
Los Angeles Lakers|Basketball team
Golden State Warriors|Basketball team
Boston Celtics|Basketball team
Chicago Bulls|Basketball team
Miami Heat|Basketball team
Brooklyn Nets|Basketball team
New York Knicks|Basketball team
Dallas Mavericks|Basketball team
Milwaukee Bucks|Basketball team
D'Tigers|National team
Tom Brady|American football player
Patrick Mahomes|American football player
Kansas City Chiefs|American football team
Dallas Cowboys|American football team
San Francisco 49ers|American football team
New England Patriots|American football team
Serena Williams|Tennis player
Venus Williams|Tennis player
Roger Federer|Tennis player
Rafael Nadal|Tennis player
Novak Djokovic|Tennis player
Carlos Alcaraz|Tennis player
Naomi Osaka|Tennis player
Coco Gauff|Tennis player
Usain Bolt|Athlete
Eliud Kipchoge|Athlete
Simone Biles|Gymnast
Michael Phelps|Swimmer
Tobi Amusan|Athlete
Blessing Okagbare|Athlete
Anthony Joshua|Boxer
Tyson Fury|Boxer
Canelo Alvarez|Boxer
Floyd Mayweather|Boxer
Mike Tyson|Boxer
Muhammad Ali|Boxer
Francis Ngannou|MMA fighter
Israel Adesanya|MMA fighter
Kamaru Usman|MMA fighter
Conor McGregor|MMA fighter
Lewis Hamilton|Formula 1 driver
Max Verstappen|Formula 1 driver
Charles Leclerc|Formula 1 driver
Ferrari|Formula 1 team
Red Bull Racing|Formula 1 team
Mercedes-AMG Petronas|Formula 1 team
McLaren|Formula 1 team
Virat Kohli|Cricketer
Sachin Tendulkar|Cricketer
MS Dhoni|Cricketer
Mumbai Indians|Cricket team
Chennai Super Kings|Cricket team
Tiger Woods|Golfer
Rory McIlroy|Golfer
Football|Sport
Basketball|Sport
Tennis|Sport
Boxing|Sport
Athletics|Sport
Formula 1|Sport
Cricket|Sport
Rugby|Sport
Volleyball|Sport
Swimming|Sport
Cycling|Sport
Wrestling|Sport
UFC|Sport
WWE|Sport
''';

const String kLanguagesRaw = r'''
English
French
Spanish
Arabic
Portuguese
Swahili
Hausa
Yoruba
Igbo
Pidgin English
Amharic
Zulu
Xhosa
Afrikaans
Shona
Twi
Ga
Ewe
Fula
Kanuri
Tiv
Efik
Ibibio
Edo
Urhobo
Igala
Nupe
Idoma
Ijaw
Itsekiri
Somali
Oromo
Tigrinya
Kinyarwanda
Luganda
Lingala
Wolof
Bambara
Mandinka
Malagasy
Mandarin Chinese
Cantonese
Hindi
Bengali
Urdu
Punjabi
Tamil
Telugu
Marathi
Gujarati
Malayalam
Kannada
Nepali
Sinhala
Japanese
Korean
Vietnamese
Thai
Indonesian
Malay
Filipino
Tagalog
Burmese
Khmer
Persian
Turkish
Hebrew
Kurdish
Pashto
German
Italian
Dutch
Swedish
Norwegian
Danish
Finnish
Icelandic
Polish
Czech
Slovak
Hungarian
Romanian
Bulgarian
Serbian
Croatian
Greek
Russian
Ukrainian
Albanian
Latin
Esperanto
Haitian Creole
Sign language
''';

// Places: `City|Country`. Countries are listed with the subtitle `Country`.
const String kPlacesRaw = r'''
Lagos|Nigeria
Abuja|Nigeria
Port Harcourt|Nigeria
Ibadan|Nigeria
Kano|Nigeria
Benin City|Nigeria
Kaduna|Nigeria
Enugu|Nigeria
Owerri|Nigeria
Aba|Nigeria
Onitsha|Nigeria
Warri|Nigeria
Asaba|Nigeria
Calabar|Nigeria
Uyo|Nigeria
Abeokuta|Nigeria
Akure|Nigeria
Ado-Ekiti|Nigeria
Osogbo|Nigeria
Ilorin|Nigeria
Jos|Nigeria
Maiduguri|Nigeria
Sokoto|Nigeria
Yola|Nigeria
Makurdi|Nigeria
Lokoja|Nigeria
Minna|Nigeria
Awka|Nigeria
Umuahia|Nigeria
Abakaliki|Nigeria
Yenagoa|Nigeria
Ikeja|Nigeria
Lekki|Nigeria
Victoria Island|Nigeria
Ikorodu|Nigeria
Epe|Nigeria
Badagry|Nigeria
Ogun State|Nigeria
Lagos State|Nigeria
Oyo State|Nigeria
Rivers State|Nigeria
Delta State|Nigeria
Edo State|Nigeria
Anambra State|Nigeria
Imo State|Nigeria
Abia State|Nigeria
Enugu State|Nigeria
Kaduna State|Nigeria
Kano State|Nigeria
Accra|Ghana
Kumasi|Ghana
Tema|Ghana
Takoradi|Ghana
Cape Coast|Ghana
Nairobi|Kenya
Mombasa|Kenya
Kisumu|Kenya
Nakuru|Kenya
Eldoret|Kenya
Kampala|Uganda
Entebbe|Uganda
Kigali|Rwanda
Dar es Salaam|Tanzania
Dodoma|Tanzania
Arusha|Tanzania
Zanzibar|Tanzania
Addis Ababa|Ethiopia
Johannesburg|South Africa
Cape Town|South Africa
Durban|South Africa
Pretoria|South Africa
Port Elizabeth|South Africa
Bloemfontein|South Africa
Harare|Zimbabwe
Lusaka|Zambia
Gaborone|Botswana
Windhoek|Namibia
Maputo|Mozambique
Luanda|Angola
Kinshasa|DR Congo
Brazzaville|Congo
Douala|Cameroon
Yaounde|Cameroon
Libreville|Gabon
Abidjan|Ivory Coast
Dakar|Senegal
Bamako|Mali
Ouagadougou|Burkina Faso
Niamey|Niger
Lome|Togo
Cotonou|Benin
Freetown|Sierra Leone
Monrovia|Liberia
Conakry|Guinea
Banjul|Gambia
Casablanca|Morocco
Marrakech|Morocco
Rabat|Morocco
Tunis|Tunisia
Algiers|Algeria
Cairo|Egypt
Alexandria|Egypt
Khartoum|Sudan
Mogadishu|Somalia
New York City|USA
Los Angeles|USA
Chicago|USA
Houston|USA
Dallas|USA
Atlanta|USA
Miami|USA
Washington, D.C.|USA
Boston|USA
Philadelphia|USA
San Francisco|USA
San Diego|USA
Seattle|USA
Las Vegas|USA
Phoenix|USA
Denver|USA
Austin|USA
Detroit|USA
Minneapolis|USA
Charlotte|USA
Orlando|USA
Baltimore|USA
Columbus|USA
Indianapolis|USA
Nashville|USA
New Orleans|USA
San Jose|USA
Portland|USA
Raleigh|USA
Honolulu|USA
Toronto|Canada
Vancouver|Canada
Montreal|Canada
Calgary|Canada
Ottawa|Canada
Edmonton|Canada
Winnipeg|Canada
Mexico City|Mexico
Cancun|Mexico
Guadalajara|Mexico
Havana|Cuba
Kingston|Jamaica
Port of Spain|Trinidad and Tobago
Nassau|Bahamas
Sao Paulo|Brazil
Rio de Janeiro|Brazil
Brasilia|Brazil
Salvador|Brazil
Buenos Aires|Argentina
Santiago|Chile
Lima|Peru
Bogota|Colombia
Medellin|Colombia
Caracas|Venezuela
Quito|Ecuador
Montevideo|Uruguay
London|United Kingdom
Manchester|United Kingdom
Birmingham|United Kingdom
Liverpool|United Kingdom
Leeds|United Kingdom
Glasgow|United Kingdom
Edinburgh|United Kingdom
Bristol|United Kingdom
Sheffield|United Kingdom
Newcastle|United Kingdom
Leicester|United Kingdom
Nottingham|United Kingdom
Cardiff|United Kingdom
Belfast|United Kingdom
Dublin|Ireland
Paris|France
Marseille|France
Lyon|France
Nice|France
Berlin|Germany
Munich|Germany
Frankfurt|Germany
Hamburg|Germany
Cologne|Germany
Madrid|Spain
Barcelona|Spain
Valencia|Spain
Seville|Spain
Lisbon|Portugal
Porto|Portugal
Rome|Italy
Milan|Italy
Naples|Italy
Venice|Italy
Florence|Italy
Amsterdam|Netherlands
Rotterdam|Netherlands
The Hague|Netherlands
Brussels|Belgium
Zurich|Switzerland
Geneva|Switzerland
Vienna|Austria
Stockholm|Sweden
Oslo|Norway
Copenhagen|Denmark
Helsinki|Finland
Reykjavik|Iceland
Warsaw|Poland
Prague|Czech Republic
Budapest|Hungary
Bucharest|Romania
Athens|Greece
Istanbul|Turkey
Ankara|Turkey
Moscow|Russia
Saint Petersburg|Russia
Kyiv|Ukraine
Dubai|United Arab Emirates
Abu Dhabi|United Arab Emirates
Doha|Qatar
Riyadh|Saudi Arabia
Jeddah|Saudi Arabia
Mecca|Saudi Arabia
Medina|Saudi Arabia
Kuwait City|Kuwait
Manama|Bahrain
Muscat|Oman
Amman|Jordan
Beirut|Lebanon
Jerusalem|Israel
Tel Aviv|Israel
Tehran|Iran
Baghdad|Iraq
Karachi|Pakistan
Lahore|Pakistan
Islamabad|Pakistan
Delhi|India
Mumbai|India
Bengaluru|India
Hyderabad|India
Chennai|India
Kolkata|India
Pune|India
Dhaka|Bangladesh
Colombo|Sri Lanka
Kathmandu|Nepal
Beijing|China
Shanghai|China
Shenzhen|China
Guangzhou|China
Hong Kong|China
Taipei|Taiwan
Tokyo|Japan
Osaka|Japan
Kyoto|Japan
Seoul|South Korea
Busan|South Korea
Singapore|Singapore
Kuala Lumpur|Malaysia
Bangkok|Thailand
Phuket|Thailand
Hanoi|Vietnam
Ho Chi Minh City|Vietnam
Jakarta|Indonesia
Bali|Indonesia
Manila|Philippines
Sydney|Australia
Melbourne|Australia
Brisbane|Australia
Perth|Australia
Canberra|Australia
Auckland|New Zealand
Wellington|New Zealand
Nigeria|Country
Ghana|Country
Kenya|Country
Uganda|Country
Tanzania|Country
Rwanda|Country
Ethiopia|Country
South Africa|Country
Zimbabwe|Country
Zambia|Country
Botswana|Country
Namibia|Country
Mozambique|Country
Angola|Country
Cameroon|Country
Ivory Coast|Country
Senegal|Country
Mali|Country
Niger|Country
Togo|Country
Benin|Country
Sierra Leone|Country
Liberia|Country
Gambia|Country
Morocco|Country
Tunisia|Country
Algeria|Country
Egypt|Country
Sudan|Country
Somalia|Country
DR Congo|Country
United States|Country
Canada|Country
Mexico|Country
Cuba|Country
Jamaica|Country
Brazil|Country
Argentina|Country
Chile|Country
Peru|Country
Colombia|Country
Venezuela|Country
United Kingdom|Country
Ireland|Country
France|Country
Germany|Country
Spain|Country
Portugal|Country
Italy|Country
Netherlands|Country
Belgium|Country
Switzerland|Country
Austria|Country
Sweden|Country
Norway|Country
Denmark|Country
Finland|Country
Iceland|Country
Poland|Country
Czech Republic|Country
Hungary|Country
Romania|Country
Greece|Country
Turkey|Country
Russia|Country
Ukraine|Country
United Arab Emirates|Country
Qatar|Country
Saudi Arabia|Country
Kuwait|Country
Jordan|Country
Lebanon|Country
Israel|Country
Iran|Country
Iraq|Country
Pakistan|Country
India|Country
Bangladesh|Country
Sri Lanka|Country
Nepal|Country
China|Country
Taiwan|Country
Japan|Country
South Korea|Country
Singapore|Country
Malaysia|Country
Thailand|Country
Vietnam|Country
Indonesia|Country
Philippines|Country
Australia|Country
New Zealand|Country
''';


