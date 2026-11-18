# Partnership request emails (drafts)

Replace the [brackets]. Send from a professional address. Never include passwords or keys.

---
## 1. Uber: Business Development / Developer Platform
**To:** via https://developer.uber.com (Contact / "Talk to us") and Uber India Business Development
**Subject:** API access request: ride fare & ETA estimates for RideCompare (India)

Hello Uber Business Development team,

I'm [Name], [role] at [Company]. We're building RideCompare, a mobile app for India that shows riders an
estimated fare and pickup time for a trip from several ride services in one screen.

We'd like to request access to the Rides API estimate endpoints (`GET /v1.2/estimates/price` and
`GET /v1.2/estimates/time`) for India.

We know that § II B of the API Terms of Use restricts price comparison with competitors. So we're asking for
**written permission** for this use case, under whatever conditions Uber requires (attribution, display rules,
rate limits, a commercial agreement).

Key facts:
- We show estimates only. We don't book rides, take payments or redirect users.
- Uber estimates would be clearly labelled, attributed to Uber and cached for no longer than you specify.
- Expected volume at launch: about [N] estimate requests/day in [cities].
- We use server-side tokens only, stored in a secrets manager.

Can we set up a short call? Happy to share a demo build.

Best regards,
[Name] · [Company] · [Phone] · [Website]

---
## 2. Ola: Affiliates programme
**To:** affiliates@olacabs.com
**Subject:** Affiliate API access: ride estimates for RideCompare

Hello Ola Affiliates team,

I'm [Name] from [Company]. We're building RideCompare, an Indian mobile app that shows riders estimated fares
and ETAs for Bike, Auto and Car trips. We'd like to join the Ola affiliate programme and get sandbox access and an
`X-APP-TOKEN` for the ride availability and estimate APIs.

- Estimates only. We don't book rides or take payments.
- Ola options would be shown with Ola branding and labelled as Ola estimates.
- Launch cities: [cities]; expected volume about [N] requests/day.
- The integration is ready to test against your sandbox.

Please let us know the eligibility criteria and next steps.

Regards,
[Name] · [Company] · [Phone] · [Website]

---
## 3. Rapido: Business partnerships
**To:** Rapido partnerships / business team (via rapido.bike contact page or LinkedIn business development)
**Subject:** Partnership enquiry: official fare-estimate API for RideCompare

Hello Rapido team,

I'm [Name] from [Company]. RideCompare is a mobile app that shows riders estimated fares and pickup times for
Bike, Auto and Car rides in [cities].

We'd like to know whether Rapido offers an official partner API, or an ONDC listing for ride hailing, that
provides fare and ETA estimates for a pickup and drop location. We'd use it only to display clearly attributed
Rapido estimates. We don't book rides or take payments, and we won't access Rapido data any other way.

If there is a programme, we'd be grateful for documentation and the eligibility criteria.

Thanks,
[Name] · [Company] · [Phone] · [Website]

---
## 4. ONDC: Mobility buyer app enquiry
**To:** techsupport@ondc.org (and the mobility team via https://portal.ondc.org)
**Subject:** Mobility (TRV10) buyer app: is a search-only fare display app allowed?

Hello ONDC team,

We're [Company], building RideCompare, an app that shows riders ride options and fares for a trip.
We'd like to join the network as a mobility buyer app (TRV10, ops_no 1). Before we begin onboarding:

1. May a buyer app use `search/on_search` to **display quotes only**, without the select/init/confirm booking
   flow? Or must every buyer app support booking?
2. What entity, compliance and commercial requirements apply to a mobility buyer app (company registration, fees, agreements)?
3. Which ride-hailing seller apps are live today, and in which cities (especially Delhi NCR and Bengaluru)?
4. Is pre-production access available for testing against the reference seller apps?

Thank you,
[Name] · [Company] · [Phone] · [Website]
