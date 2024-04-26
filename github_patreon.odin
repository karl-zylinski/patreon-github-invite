package github_patreon

import "curl"
import "core:fmt"
import "core:mem"
import "base:runtime"
import "core:encoding/json"
import "core:strconv"
import "core:os"
import "core:slice"

SourceCodeTier :: 22839927
SuperTier :: 22840288


curl_get :: proc(url: string, header_strings: []string) -> ([]byte, bool) {
	h := curl.easy_init()
	defer curl.easy_cleanup(h)

	headers: ^curl.curl_slist

	for h in header_strings {
		headers = curl.slist_append(headers, fmt.ctprintf("%v", h))
	}
	defer curl.slist_free_all(headers)

	curl.easy_setopt(h, .URL, fmt.ctprintf("%v", url))
	hres := curl.easy_setopt(h, .HTTPHEADER, headers)

	if hres != .OK {
		fmt.println("Failed to set HTTPHEADER: ", curl.easy_strerror(hres))
	}

	DataContext :: struct {
		data: []u8,
		ctx:  runtime.Context,
	}

	write_callback :: proc "c" (contents: [^]u8, size: uint, nmemb: uint, userp: rawptr) -> uint {
		dc := transmute(^DataContext)userp
		context = dc.ctx
		total_size := size * nmemb
		dc.data = make([]u8, int(total_size)) // <-- ALLOCATION
		mem.copy(raw_data(dc.data), contents, int(total_size))
		return total_size
	}

	data := DataContext{nil, context}
	curl.easy_setopt(h, .WRITEFUNCTION, write_callback)
	curl.easy_setopt(h, .WRITEDATA, &data)
	curl.easy_setopt(h, .SSL_VERIFYPEER, 0)
	result := curl.easy_perform(h)

	if result != .OK {
		fmt.println("Error occurred: ", result)
		return {}, false
	}

	return data.data, true
}

get_all_emails_that_should_have_access :: proc() -> ([]string, bool) {
	url := "https://www.patreon.com/api/oauth2/v2/campaigns/973462/members?include=currently_entitled_tiers&fields%5Bmember%5D=email"
	headers := []string {
		fmt.tprintf("Authorization: Bearer %s", patreon_secret),
	}
	members_data, members_data_ok := curl_get(url, headers)

	if !members_data_ok {
		return {}, false
	}

	emails: [dynamic]string

	PatreonTierData :: struct {
		type: string,
		id: string,
	}

	PatreonMemberEntitledTiers :: struct {
		data: []PatreonTierData,
	}

	PatreonMemberAttributes :: struct {
		email: string,
	}

	PatreonMemberRelationships :: struct {
		currently_entitled_tiers: PatreonMemberEntitledTiers,
	}

	PatreonMemberData :: struct {
		attributes: PatreonMemberAttributes,
		relationships: PatreonMemberRelationships,
	}

	PatreonMembers :: struct {
		data: []PatreonMemberData,
	}

	patreon_members: PatreonMembers
	if json.unmarshal(members_data, &patreon_members) == nil {
		for d in patreon_members.data {
			if d.attributes.email == "" {
				continue
			}

			for td in d.relationships.currently_entitled_tiers.data {
				if td.type != "tier" {
					continue
				}

				id := strconv.atoi(td.id)

				if id == SourceCodeTier || id == SuperTier {
					append(&emails, d.attributes.email)
				}
			}
		}
	}

	delete(members_data)
	return emails[:], true
}

invite_to_github :: proc(email: string) -> bool {
	url := "https://api.github.com/orgs/karl-zylinski-subscribers/invitations"
	header_strings := []string {
		"User-Agent: karl-zylinski",
		"Accept: application/vnd.github+json",
		fmt.tprintf("Authorization: Bearer %s", github_secret),
		"X-GitHub-Api-Version: 2022-11-28",
	}
	
	h := curl.easy_init()
	defer curl.easy_cleanup(h)

	headers: ^curl.curl_slist

	for h in header_strings {
		headers = curl.slist_append(headers, fmt.ctprintf("%v", h))
	}
	defer curl.slist_free_all(headers)

	curl.easy_setopt(h, .URL, fmt.ctprintf("%v", url))
	hres := curl.easy_setopt(h, .HTTPHEADER, headers)

	if hres != .OK {
		fmt.println("Failed to set HTTPHEADER: ", curl.easy_strerror(hres))
	}

	hres = curl.easy_setopt(h, .POST, 1)

	if hres != .OK {
		fmt.println("Failed to to set CURLOPT_POST: ", curl.easy_strerror(hres))
	}

	hres = curl.easy_setopt(h, .POSTFIELDS, fmt.ctprintf("{{\"email\":\"%v\"}}", email))

	if hres != .OK {
		fmt.println("Failed to set CURLOPT_POSTFIELDS: ", curl.easy_strerror(hres))
	}

	DataContext :: struct {
		data: []u8,
		ctx:  runtime.Context,
	}

	write_callback :: proc "c" (contents: [^]u8, size: uint, nmemb: uint, userp: rawptr) -> uint {
		dc := transmute(^DataContext)userp
		context = dc.ctx
		total_size := size * nmemb
		dc.data = make([]u8, int(total_size)) // <-- ALLOCATION
		mem.copy(raw_data(dc.data), contents, int(total_size))
		return total_size
	}

	data := DataContext{nil, context}
	curl.easy_setopt(h, .WRITEFUNCTION, write_callback)
	curl.easy_setopt(h, .WRITEDATA, &data)
	curl.easy_setopt(h, .SSL_VERIFYPEER, 0)
	result := curl.easy_perform(h)
	res_ok := result == .OK

	if !res_ok {
		return false
	}

	result_string := string(data.data)
	fmt.println(result_string)
	return true
}

patreon_secret: string
github_secret: string

main :: proc() {
	if patreon_secret_data, patreon_secret_data_ok := os.read_entire_file("patreon_secret.txt"); patreon_secret_data_ok {
		patreon_secret = string(patreon_secret_data)
	} else {
		panic("Put patreon secret in patreon_secret.txt")
	}

	if github_secret_data, github_secret_data_ok := os.read_entire_file("github_secret.txt"); github_secret_data_ok {
		github_secret = string(github_secret_data)
	} else {
		panic("Put GitHub secret in github_secret.txt")
	}

	if emails, emails_ok := get_all_emails_that_should_have_access(); emails_ok {
		AlreadyInvited :: struct {
			already_invited: []string,
		}

		already_invited: AlreadyInvited

		if invited_file, invited_file_ok := os.read_entire_file("invited.json"); invited_file_ok {
			if json.unmarshal(invited_file, &already_invited) != nil {
				panic("Failed unmarshaling invited.json")
			}
		} else {
			panic("Failed reading invited.json")
		}

		all_invited := slice.clone_to_dynamic(already_invited.already_invited)
		to_invite: map[string]struct{}

		for e in emails {
			to_invite[e] = {}
		}

		for a in already_invited.already_invited {
			delete_key(&to_invite, a)
		}

		for e, _ in to_invite {
			if invite_to_github(e) {
				append(&all_invited, e)
			}
		}

		already_invited.already_invited = all_invited[:]

		if out, err := json.marshal(already_invited); err == nil {
			os.write_entire_file("invited.json", out)
		}
	}
}